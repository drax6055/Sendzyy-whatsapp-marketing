'use strict';

const mongoose = require('mongoose');
const axios = require('axios');
const LeadTrigger = require('../models/LeadTrigger');
const Lead = require('../models/Lead');
const PendingChatbotSession = require('../models/PendingChatbotSession');
const { GRAPH_BASE_URL } = require('../config/meta');

const specificity = t =>
  (t.adId ? 4 : 0) +
  (t.campaignId ? 3 : 0) +
  (t.formId ? 3 : 0) +
  (t.adType && t.adType !== 'any' ? 1 : 0) +
  (t.source === 'meta_ads' ? 0.5 : 0);

/**
 * Checks if contact has an ongoing active chatbot session
 */
async function hasActiveChatbotSession(tenantId, mobileNumber) {
  try {
    const ChatbotSession = mongoose.model('ChatbotSession');
    const session = await ChatbotSession.findOne({
      tenantId,
      contactId: mobileNumber,
      status: 'active'
    });
    return !!session;
  } catch (_) {
    return false;
  }
}

/**
 * Dispatches WhatsApp Template message to lead
 */
async function sendWhatsAppTemplate(tenantId, lead, trigger) {
  const Tenant = mongoose.model('Tenant');
  const tenant = await Tenant.findById(tenantId);
  if (!tenant?.whatsappConfig?.phoneNumberId || !tenant?.whatsappConfig?.accessToken) {
    console.warn(`[MetaTriggers] Tenant ${tenantId} missing WhatsApp Cloud API credentials`);
    return null;
  }

  const { phoneNumberId, accessToken, businessAccountId } = tenant.whatsappConfig;
  const url = `${GRAPH_BASE_URL}/${phoneNumberId}/messages`;

  // Fetch template info to extract {{N}} parameter count
  let components = [];
  try {
    const resp = await axios.get(
      `${GRAPH_BASE_URL}/${businessAccountId}/message_templates`,
      {
        headers: { Authorization: `Bearer ${accessToken}` },
        params: { name: trigger.templateName }
      }
    );
    const tpl = (resp.data?.data || []).find(t => t.name === trigger.templateName);
    components = tpl?.components || [];
  } catch (_) {}

  const bodyComponent = components.find(c => c.type === 'BODY');
  const matches = bodyComponent?.text ? (bodyComponent.text.match(/\{\{\d+\}\}/g) || []) : [];
  const varCount = new Set(matches.map(m => parseInt(m.replace(/\D/g, '')))).size;

  const mapping = trigger.variableMapping || {};
  const autoFields = ['name', 'mobileNumber', 'email', 'companyName', 'formName'];
  const resolvedMapping = { ...mapping };

  if (varCount > 0) {
    let autoIdx = 0;
    for (let i = 1; i <= varCount; i++) {
      if (!resolvedMapping[String(i)]) {
        resolvedMapping[String(i)] = autoFields[autoIdx] || 'name';
        autoIdx++;
      }
    }
  }

  const bodyParams = Object.keys(resolvedMapping)
    .sort((a, b) => parseInt(a) - parseInt(b))
    .map(k => {
      const field = resolvedMapping[k];
      let val = lead[field] ?? '';
      if (!val && lead.meta && lead.meta[field]) val = lead.meta[field];
      if (!val && lead.metadata && lead.metadata[field]) val = lead.metadata[field];
      return { type: 'text', text: String(val || '') };
    });

  const payload = {
    messaging_product: 'whatsapp',
    to: lead.mobileNumber,
    type: 'template',
    template: {
      name: trigger.templateName,
      language: { code: trigger.templateLanguage || 'en_US' }
    }
  };

  const templateComponents = [];
  if (trigger.mediaId) {
    const mediaType = (trigger.mediaType || 'image').toLowerCase();
    templateComponents.push({
      type: 'header',
      parameters: [{ type: mediaType, [mediaType]: { id: trigger.mediaId } }]
    });
  }
  if (bodyParams.length) {
    templateComponents.push({ type: 'body', parameters: bodyParams });
  }
  if (templateComponents.length) {
    payload.template.components = templateComponents;
  }

  const res = await axios.post(url, payload, {
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' }
  });

  const wamid = res.data?.messages?.[0]?.id || null;

  // Track conversation and outgoing message
  try {
    const Conversation = mongoose.model('Conversation');
    const Message = mongoose.model('Message');
    const contactName = lead.name || lead.mobileNumber;

    await Conversation.findOneAndUpdate(
      { tenantId, contactId: lead.mobileNumber },
      { name: contactName, lastMessage: `📋 Template: ${trigger.templateName}`, lastActive: new Date() },
      { upsert: true }
    );

    await Message.create({
      tenantId,
      contactId: lead.mobileNumber,
      text: `📋 Template: ${trigger.templateName}`,
      isMe: true,
      time: new Date().toISOString(),
      messageType: 'template',
      templateName: trigger.templateName,
      wamid,
      status: 'sent'
    });
  } catch (dbErr) {
    console.error('[MetaTriggers] Message recording error:', dbErr.message);
  }

  return wamid;
}

/**
 * Starts chatbot session for a contact
 */
async function launchChatbot(tenantId, lead, trigger) {
  if (!trigger.chatbotId) return;

  try {
    const ChatbotSession = mongoose.model('ChatbotSession');
    const Chatbot = mongoose.model('Chatbot');

    const bot = await Chatbot.findOne({ tenantId, _id: trigger.chatbotId, isActive: true });
    if (!bot) {
      console.warn(`[MetaTriggers] Chatbot ${trigger.chatbotId} not found or inactive`);
      return;
    }

    const startNode = (bot.nodes || []).find(n => n.type === 'start') || (bot.nodes || [])[0];
    if (!startNode) return;

    await ChatbotSession.findOneAndUpdate(
      { tenantId, contactId: lead.mobileNumber },
      {
        tenantId,
        contactId: lead.mobileNumber,
        chatbotId: trigger.chatbotId,
        currentNodeId: startNode.id,
        context: {
          leadId: lead._id,
          source: lead.source,
          name: lead.name,
          formName: lead.meta?.formName || lead.formName
        },
        status: 'active',
        lastInteractionAt: new Date()
      },
      { upsert: true }
    );

    console.log(`[MetaTriggers] Chatbot ${trigger.chatbotId} initialized for ${lead.mobileNumber}`);
  } catch (err) {
    console.error('[MetaTriggers] launchChatbot error:', err.message);
  }
}

/**
 * Evaluates triggers matching a new lead event
 */
async function evaluateMetaTriggers({ tenantId, lead, touchpoint }) {
  if (!lead.mobileNumber) return { skipped: 'no_phone' };
  if (lead.optedOut) return { skipped: 'opted_out' };

  // Strict Policy: Instant Forms MUST start with an approved template (24h window constraint)
  // CTWA can start the chatbot directly since the prospect messaged first.
  const action = touchpoint.adType === 'instant_form' ? 'send_template' : 'start_chatbot';

  const candidates = await LeadTrigger.find({
    tenantId,
    isActive: true,
    action,
    source: { $in: ['meta_ads', 'any'] },
    adType: { $in: [touchpoint.adType, 'any'] }
  });

  const matches = candidates.filter(t =>
    (!t.formId || t.formId === touchpoint.formId) &&
    (!t.campaignId || t.campaignId === touchpoint.campaignId) &&
    (!t.adId || t.adId === touchpoint.adId)
  );

  if (!matches.length) return { skipped: 'no_trigger' };

  // Highest specificity wins
  const trigger = matches.sort((a, b) => specificity(b) - specificity(a))[0];

  if (trigger.requireConsent && !touchpoint.consentAnswer) {
    return { skipped: 'no_consent' };
  }

  if (action === 'send_template') {
    const cooldownMs = (trigger.cooldownDays || 7) * 864e5;
    if (lead.lastTemplateSentAt && Date.now() - new Date(lead.lastTemplateSentAt).getTime() < cooldownMs) {
      return { skipped: 'cooldown' };
    }

    try {
      await sendWhatsAppTemplate(tenantId, lead, trigger);
      await Lead.updateOne(
        { _id: lead._id },
        {
          $set: {
            lastTemplateSentAt: new Date(),
            status: lead.status === 'new' ? 'contacted' : lead.status
          }
        }
      );

      if (trigger.chatbotId) {
        // Register pending chatbot session to trigger as soon as the lead replies
        await PendingChatbotSession.findOneAndUpdate(
          { tenantId, mobileNumber: lead.mobileNumber, consumedAt: { $exists: false } },
          {
            tenantId,
            mobileNumber: lead.mobileNumber,
            chatbotId: trigger.chatbotId,
            leadId: lead._id,
            expiresAt: new Date(Date.now() + 7 * 864e5) // 7-day TTL
          },
          { upsert: true }
        );
      }
      return { ok: 'template_sent' };
    } catch (err) {
      console.error('[MetaTriggers] Template send failed:', err.message);
      await Lead.updateOne({ _id: lead._id }, { $set: { status: 'failed' } });
      return { error: err.message };
    }
  }

  // CTWA Direct Chatbot branch
  if (await hasActiveChatbotSession(tenantId, lead.mobileNumber)) {
    return { skipped: 'session_already_active' };
  }

  await launchChatbot(tenantId, lead, trigger);
  await Lead.updateOne(
    { _id: lead._id },
    { $set: { status: lead.status === 'new' ? 'contacted' : lead.status } }
  );
  return { ok: 'chatbot_started' };
}

/**
 * Called on any inbound WhatsApp message: checks if lead has a pending chatbot session waiting for customer reply.
 */
async function maybeStartPendingChatbot(tenantId, fromNumber) {
  try {
    const cleanNumber = String(fromNumber).replace(/\D/g, '');
    const pending = await PendingChatbotSession.findOneAndUpdate(
      {
        tenantId,
        mobileNumber: cleanNumber,
        consumedAt: { $exists: false },
        expiresAt: { $gt: new Date() }
      },
      { consumedAt: new Date() }
    );

    if (!pending) return false;
    if (await hasActiveChatbotSession(tenantId, cleanNumber)) return false;

    const lead = await Lead.findById(pending.leadId);
    if (lead) {
      await launchChatbot(tenantId, lead, { chatbotId: pending.chatbotId });
      await Lead.updateOne({ _id: pending.leadId }, { $set: { status: 'engaged' } });
      console.log(`[MetaTriggers] Lead ${lead._id} replied to template -> chatbot launched & status updated to engaged`);
      return true;
    }
  } catch (err) {
    console.error('[MetaTriggers] maybeStartPendingChatbot error:', err.message);
  }
  return false;
}

module.exports = {
  evaluateMetaTriggers,
  maybeStartPendingChatbot,
  sendWhatsAppTemplate,
  launchChatbot
};
