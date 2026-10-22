'use strict';

const mongoose = require('mongoose');
const MetaPageConnection = require('../models/MetaPageConnection');
const MetaLeadForm = require('../models/MetaLeadForm');
const MetaLeadEvent = require('../models/MetaLeadEvent');
const MetaCache = require('../models/MetaCache');
const Lead = require('../models/Lead');
const { decryptToken } = require('../utils/cryptoUtils');
const { graphGet } = require('./metaGraphClient');
const { LEAD_FIELDS } = require('../config/meta');
const { parseLeadFields } = require('./parseLeadFields');
const { claimEvent, upsertLeadWithTouchpoint } = require('./metaLeadCore');
const { evaluateMetaTriggers } = require('./metaTriggers');

/**
 * Resolves form name using cached lookup or Graph API
 */
async function getFormName(formId, pageToken, conn) {
  if (!formId) return 'Instant Form';
  const key = `form:${formId}`;
  try {
    const hit = await MetaCache.findOne({ key, expiresAt: { $gt: new Date() } });
    if (hit && hit.value) return hit.value;

    const f = await graphGet(`/${formId}`, { fields: 'name', access_token: pageToken }, conn);
    const name = f?.name || 'Instant Form';
    await MetaCache.updateOne(
      { key },
      { value: name, expiresAt: new Date(Date.now() + 864e5) },
      { upsert: true }
    );
    return name;
  } catch (_) {
    return 'Instant Form';
  }
}

/**
 * Gets tenant's configured default country code (fallback 'IN')
 */
async function getTenantDefaultCountry(tenantId) {
  try {
    const Tenant = mongoose.model('Tenant');
    const tenant = await Tenant.findById(tenantId);
    return tenant?.defaultCountry || 'IN';
  } catch (_) {
    return 'IN';
  }
}

/**
 * Core processor for Instant Form (Facebook/Instagram Lead Ads) leads.
 * Called by webhook queue and reconciliation cron.
 * 
 * @param {Object} params
 * @param {string} params.pageId - Facebook Page ID
 * @param {string} params.leadgenId - Meta Leadgen ID
 * @param {string} [params.formId] - Optional Instant Form ID
 * @param {Object} [params.prefetched] - Optional raw lead object if already fetched by cron
 */
async function ingestInstantFormLead({ pageId, leadgenId, formId, prefetched }) {
  if (!leadgenId) return { skipped: 'missing_leadgen_id' };

  const conn = await MetaPageConnection.findOne({ pageId: String(pageId), status: 'active' });
  if (!conn) {
    console.warn(`[MetaLeadIngestion] No active MetaPageConnection found for pageId: ${pageId}`);
    return { skipped: 'no_active_connection' };
  }

  const { tenantId } = conn;
  const dedupeKey = `lf:${leadgenId}`;

  // Check if form has syncEnabled: false
  if (formId) {
    const formDoc = await MetaLeadForm.findOne({ tenantId, formId: String(formId) });
    if (formDoc && formDoc.syncEnabled === false) {
      console.log(`[MetaLeadIngestion] Form ${formId} has sync disabled. Skipping lead ${leadgenId}.`);
      return { skipped: 'sync_disabled' };
    }
  }

  // Claim event in idempotency ledger
  const ev = await claimEvent(tenantId, dedupeKey, 'instant_form', { pageId, formId });
  if (ev.status === 'done') {
    return { skipped: 'duplicate_already_processed' };
  }

  try {
    let lead;
    let touchpoint;

    if (ev.status === 'lead_saved' && ev.leadId) {
      // Resume if lead was already saved previously
      lead = await Lead.findById(ev.leadId);
      touchpoint = (lead?.touchpoints || []).find(t => t.dedupeKey === dedupeKey);
    } else {
      const pageToken = decryptToken(conn.pageAccessToken);
      const raw = prefetched || await graphGet(`/${leadgenId}`, { fields: LEAD_FIELDS, access_token: pageToken }, conn);

      const resolvedFormId = raw.form_id || formId || '';
      const formName = await getFormName(resolvedFormId, pageToken, conn);
      const country = await getTenantDefaultCountry(tenantId);
      const parsed = parseLeadFields(raw.field_data || [], country);

      const isIg = raw.platform === 'instagram' || raw.platform === 'ig';
      const platform = isIg ? 'ig' : (raw.platform === 'fb' ? 'fb' : 'unknown');

      touchpoint = {
        dedupeKey,
        source: 'meta_ads',
        adType: 'instant_form',
        platform,
        isOrganic: Boolean(raw.is_organic),
        pageId,
        pageName: conn.pageName || '',
        formId: resolvedFormId,
        formName,
        adId: raw.ad_id || '',
        adName: raw.ad_name || '',
        adsetId: raw.adset_id || '',
        adsetName: raw.adset_name || '',
        campaignId: raw.campaign_id || '',
        campaignName: raw.campaign_name || '',
        leadgenId,
        consentQuestion: parsed.consent?.question || '',
        consentAnswer: parsed.consent?.answer || '',
        consentRecordedAt: parsed.consent ? new Date(raw.created_time || Date.now()) : undefined,
        at: new Date(raw.created_time || Date.now())
      };

      lead = await upsertLeadWithTouchpoint({
        tenantId,
        phone: parsed.phone.valid ? parsed.phone.digits : '',
        invalidPhoneRaw: parsed.phone.raw,
        name: parsed.name,
        email: parsed.email,
        companyName: parsed.companyName,
        custom: parsed.custom,
        touchpoint
      });

      await MetaLeadEvent.updateOne(
        { tenantId, dedupeKey },
        { status: 'lead_saved', leadId: lead._id, rawPayload: raw }
      );
    }

    if (lead && touchpoint) {
      await evaluateMetaTriggers({ tenantId, lead, touchpoint });
    }

    await MetaLeadEvent.updateOne({ tenantId, dedupeKey }, { status: 'done' });
    console.log(`[MetaLeadIngestion] Successfully ingested lead ${lead?._id} (${dedupeKey}) for tenant ${tenantId}`);
    return { ok: true, leadId: lead?._id };
  } catch (err) {
    console.error(`[MetaLeadIngestion] Error processing ${dedupeKey}:`, err.message);
    await MetaLeadEvent.updateOne(
      { tenantId, dedupeKey },
      { status: 'failed', error: String(err.message).slice(0, 300) }
    );
    throw err;
  }
}

module.exports = {
  ingestInstantFormLead,
  getFormName
};
