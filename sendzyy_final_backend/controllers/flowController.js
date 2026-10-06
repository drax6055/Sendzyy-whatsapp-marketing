const WhatsAppFlow = require('../models/WhatsAppFlow');
const WhatsAppFlowResponse = require('../models/WhatsAppFlowResponse');
const { WhatsAppFlowService, compileFieldsToFlowJson } = require('../services/WhatsAppFlowService');

/**
 * Controller for WhatsApp Flows management and interactions
 */
function createFlowController(dependencies = {}) {
    const { Tenant, Message, Conversation, StatusMapping, broadcastMessages, broadcastConversations } = dependencies;

    return {
        // GET /api/flows
        async getFlows(req, res) {
            try {
                const tenantId = req.user.tenantId;
                const { sync } = req.query;

                if (sync === 'true') {
                    const tenant = await Tenant.findById(tenantId);
                    if (tenant && tenant.whatsappConfig?.businessAccountId && tenant.whatsappConfig?.accessToken) {
                        try {
                            await WhatsAppFlowService.syncFlowsFromMeta(tenant);
                        } catch (syncErr) {
                            console.warn('[FlowController] Meta sync warning:', syncErr.response?.data || syncErr.message);
                        }
                    }
                }

                const flows = await WhatsAppFlow.find({ tenantId }).sort({ updatedAt: -1 }).lean();

                // Enrich with response counts
                const flowIds = flows.map(f => f.flowId);
                const counts = await WhatsAppFlowResponse.aggregate([
                    { $match: { tenantId, flowId: { $in: flowIds } } },
                    { $group: { _id: '$flowId', count: { $sum: 1 } } }
                ]);
                const countMap = {};
                counts.forEach(c => { countMap[c._id] = c.count; });

                const enriched = flows.map(f => ({
                    ...f,
                    submissionsCount: countMap[f.flowId] || 0
                }));

                res.json({ success: true, flows: enriched });
            } catch (err) {
                console.error('[FlowController] getFlows error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/flows
        async createFlow(req, res) {
            try {
                const tenantId = req.user.tenantId;
                const tenant = await Tenant.findById(tenantId);
                if (!tenant) return res.status(404).json({ success: false, error: 'Tenant not found' });

                const {
                    name,
                    categories,
                    fieldsConfig,
                    flowJson,
                    ctaText,
                    headerText,
                    bodyText,
                    footerText,
                    autoPublish
                } = req.body;

                if (!name || name.trim() === '') {
                    return res.status(400).json({ success: false, error: 'Flow name is required' });
                }

                const created = await WhatsAppFlowService.createAndPublishFlow(tenant, {
                    name: name.trim(),
                    categories: categories || ['LEAD_GENERATION'],
                    fieldsConfig: fieldsConfig || [],
                    flowJson,
                    ctaText: ctaText || 'Open Form',
                    headerText: headerText || '',
                    bodyText: bodyText || '',
                    footerText: footerText || 'Powered by Sendzyy',
                    autoPublish: autoPublish !== false
                });

                res.status(201).json({ success: true, flow: created });
            } catch (err) {
                console.error('[FlowController] createFlow error:', err.response?.data || err);
                const metaErr = err.response?.data?.error?.message || err.message;
                res.status(400).json({ success: false, error: metaErr });
            }
        },

        // GET /api/flows/:flowId
        async getFlowById(req, res) {
            try {
                const tenantId = req.user.tenantId;
                const { flowId } = req.params;

                const flow = await WhatsAppFlow.findOne({ tenantId, flowId }).lean();
                if (!flow) return res.status(404).json({ success: false, error: 'Flow not found' });

                const submissionsCount = await WhatsAppFlowResponse.countDocuments({ tenantId, flowId });
                res.json({ success: true, flow: { ...flow, submissionsCount } });
            } catch (err) {
                console.error('[FlowController] getFlowById error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/flows/:flowId/publish
        async publishFlow(req, res) {
            try {
                const tenantId = req.user.tenantId;
                const tenant = await Tenant.findById(tenantId);
                if (!tenant) return res.status(404).json({ success: false, error: 'Tenant not found' });

                const { flowId } = req.params;
                await WhatsAppFlowService.publishFlow(tenant, flowId);
                res.json({ success: true, message: 'Flow successfully published on Meta WABA!' });
            } catch (err) {
                console.error('[FlowController] publishFlow error:', err.response?.data || err);
                const metaErr = err.response?.data?.error?.message || err.message;
                res.status(400).json({ success: false, error: metaErr });
            }
        },

        // DELETE /api/flows/:flowId
        async deleteFlow(req, res) {
            try {
                const tenantId = req.user.tenantId;
                const tenant = await Tenant.findById(tenantId);
                if (!tenant) return res.status(404).json({ success: false, error: 'Tenant not found' });

                const { flowId } = req.params;
                await WhatsAppFlowService.deleteFlow(tenant, flowId);
                res.json({ success: true, message: 'Flow deleted successfully' });
            } catch (err) {
                console.error('[FlowController] deleteFlow error:', err.response?.data || err);
                const metaErr = err.response?.data?.error?.message || err.message;
                res.status(400).json({ success: false, error: metaErr });
            }
        },

        // POST /api/flows/send
        async sendFlow(req, res) {
            try {
                const tenantId = req.user.tenantId;
                const tenant = await Tenant.findById(tenantId);
                if (!tenant) return res.status(404).json({ success: false, error: 'Tenant not found' });

                const {
                    to,
                    flowId,
                    headerText,
                    bodyText,
                    footerText,
                    ctaText,
                    screenId
                } = req.body;

                if (!to || !flowId) {
                    return res.status(400).json({ success: false, error: 'Recipient phone (to) and flowId are required' });
                }

                const flowDoc = await WhatsAppFlow.findOne({ tenantId, flowId });
                const resolvedFlowName = flowDoc?.name || 'WhatsApp Flow';

                // Send via Meta Graph API
                const { wamid, flowToken } = await WhatsAppFlowService.sendFlowMessage(tenant, {
                    to,
                    flowId,
                    headerText: headerText || flowDoc?.headerText || '',
                    bodyText: bodyText || flowDoc?.bodyText || 'Please complete the form below:',
                    footerText: footerText || flowDoc?.footerText || 'Powered by Sendzyy',
                    ctaText: ctaText || flowDoc?.ctaText || 'Open Form',
                    screenId: screenId || 'QUESTION_SCREEN'
                });

                const now = new Date();
                const cleanPhone = to.replace(/[^0-9]/g, '');

                // Track in Message collection for live chat
                const savedMsg = await Message.create({
                    tenantId,
                    contactId: cleanPhone,
                    text: bodyText || `📋 ${resolvedFlowName}`,
                    isMe: true,
                    time: now.toISOString(),
                    timestamp: now,
                    messageType: 'flow',
                    source: 'chat',
                    wamid: wamid || null,
                    interactivePayload: {
                        type: 'flow',
                        flowId,
                        flowName: resolvedFlowName,
                        ctaText: ctaText || flowDoc?.ctaText || 'Open Form',
                        headerText: headerText || flowDoc?.headerText || '',
                        bodyText: bodyText || flowDoc?.bodyText || '',
                        footerText: footerText || flowDoc?.footerText || '',
                        flowToken
                    },
                    status: 'sent'
                });

                // Update Conversation lastActive
                await Conversation.findOneAndUpdate(
                    { tenantId, contactId: cleanPhone },
                    {
                        tenantId,
                        contactId: cleanPhone,
                        lastMessage: `📋 Flow: ${resolvedFlowName}`,
                        lastActive: now,
                        hasReply: true
                    },
                    { upsert: true }
                );

                if (wamid) {
                    try {
                        await StatusMapping.findOneAndUpdate(
                            { wamid },
                            { wamid, tenantId, to: cleanPhone },
                            { upsert: true }
                        );
                    } catch (_) {}
                }

                if (typeof broadcastMessages === 'function') {
                    await broadcastMessages(tenantId, cleanPhone);
                }
                if (typeof broadcastConversations === 'function') {
                    await broadcastConversations(tenantId);
                }

                res.json({ success: true, wamid, flowToken, message: savedMsg });
            } catch (err) {
                console.error('[FlowController] sendFlow error:', JSON.stringify(err.response?.data || err.message));
                const metaErr = err.response?.data?.error?.error_user_msg
                    || err.response?.data?.error?.error_data?.details
                    || err.response?.data?.error?.message 
                    || err.message;
                res.status(400).json({ success: false, error: metaErr });
            }
        },

        // GET /api/flows/:flowId/responses
        async getFlowResponses(req, res) {
            try {
                const tenantId = req.user.tenantId;
                const { flowId } = req.params;
                const limit = parseInt(req.query.limit, 10) || 50;
                const page = parseInt(req.query.page, 10) || 1;
                const skip = (page - 1) * limit;

                const query = { tenantId };
                if (flowId && flowId !== 'all') {
                    query.flowId = flowId;
                }

                const total = await WhatsAppFlowResponse.countDocuments(query);
                const responses = await WhatsAppFlowResponse.find(query)
                    .sort({ createdAt: -1 })
                    .skip(skip)
                    .limit(limit)
                    .lean();

                res.json({
                    success: true,
                    total,
                    page,
                    pages: Math.ceil(total / limit),
                    responses
                });
            } catch (err) {
                console.error('[FlowController] getFlowResponses error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        }
    };
}

module.exports = { createFlowController };
