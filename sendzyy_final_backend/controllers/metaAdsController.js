'use strict';

const MetaAdCampaign = require('../models/MetaAdCampaign');
const MetaAdToken = require('../models/MetaAdToken');
const MetaAdsService = require('../services/MetaAdsService');
const { encryptSecret, decryptSecret } = require('../cryptoUtils');

function createMetaAdsController({ Lead, Tenant, triggerLeadAction }) {
    return {
        /**
         * Connect Facebook Business Account / Token
         * POST /api/meta/auth/connect
         */
        connectAccount: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const {
                    userAccessToken,
                    adAccountId,
                    adAccountName,
                    pageId,
                    pageName,
                    instagramActorId,
                    businessId
                } = req.body;

                if (!userAccessToken) {
                    return res.status(400).json({ success: false, error: 'userAccessToken is required' });
                }

                // Exchange for long-lived user token
                let longLivedToken = userAccessToken;
                let expiresAt = null;
                try {
                    const tokenExchange = await MetaAdsService.exchangeForLongLivedToken(userAccessToken);
                    longLivedToken = tokenExchange.accessToken;
                    expiresAt = tokenExchange.expiresAt;
                } catch (tokenErr) {
                    console.warn('[metaAdsController] Token exchange warning:', tokenErr.message);
                    // If exchange fails (e.g. already long-lived or dev token), continue with provided token
                }

                // If pageId was selected, fetch page access token and subscribe webhook
                let pageAccessToken = null;
                if (pageId) {
                    try {
                        const pages = await MetaAdsService.getPages(longLivedToken);
                        const targetPage = pages.find(p => p.id === pageId);
                        if (targetPage && targetPage.access_token) {
                            pageAccessToken = targetPage.access_token;
                            // Subscribe page to leadgen webhook
                            try {
                                await MetaAdsService.subscribePageLeadWebhook(pageAccessToken, pageId);
                                console.log(`[metaAdsController] Subscribed page ${pageId} to leadgen webhook`);
                            } catch (subErr) {
                                console.warn('[metaAdsController] Webhook subscription warning:', subErr.message);
                            }
                        }
                    } catch (pageErr) {
                        console.warn('[metaAdsController] Fetch page token error:', pageErr.message);
                    }
                }

                // Encrypt secrets before storing in DB
                const encryptedAccessToken = encryptSecret(longLivedToken);
                const encryptedPageAccessToken = pageAccessToken ? encryptSecret(pageAccessToken) : null;

                const tokenDoc = await MetaAdToken.findOneAndUpdate(
                    { tenantId },
                    {
                        tenantId,
                        accessToken: encryptedAccessToken,
                        adAccountId: adAccountId || null,
                        adAccountName: adAccountName || null,
                        pageId: pageId || null,
                        pageName: pageName || null,
                        pageAccessToken: encryptedPageAccessToken,
                        instagramActorId: instagramActorId || null,
                        businessId: businessId || null,
                        status: 'connected',
                        connectedAt: new Date(),
                        expiresAt
                    },
                    { upsert: true, new: true }
                );

                return res.json({
                    success: true,
                    message: 'Facebook Business account connected successfully',
                    data: {
                        adAccountId: tokenDoc.adAccountId,
                        adAccountName: tokenDoc.adAccountName,
                        pageId: tokenDoc.pageId,
                        pageName: tokenDoc.pageName,
                        status: tokenDoc.status,
                        expiresAt: tokenDoc.expiresAt
                    }
                });
            } catch (err) {
                console.error('[metaAdsController] connectAccount error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Get Account Connection Status
         * GET /api/meta/auth/status
         */
        getAccountStatus: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const tokenDoc = await MetaAdToken.findOne({ tenantId });

                if (!tokenDoc || tokenDoc.status !== 'connected') {
                    return res.json({
                        success: true,
                        connected: false,
                        status: tokenDoc ? tokenDoc.status : 'disconnected'
                    });
                }

                return res.json({
                    success: true,
                    connected: true,
                    data: {
                        adAccountId: tokenDoc.adAccountId,
                        adAccountName: tokenDoc.adAccountName,
                        pageId: tokenDoc.pageId,
                        pageName: tokenDoc.pageName,
                        instagramActorId: tokenDoc.instagramActorId,
                        status: tokenDoc.status,
                        connectedAt: tokenDoc.connectedAt,
                        expiresAt: tokenDoc.expiresAt
                    }
                });
            } catch (err) {
                console.error('[metaAdsController] getAccountStatus error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Disconnect Account
         * POST /api/meta/auth/disconnect
         */
        disconnectAccount: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                await MetaAdToken.findOneAndUpdate(
                    { tenantId },
                    { status: 'disconnected', updatedAt: new Date() }
                );
                return res.json({ success: true, message: 'Account disconnected successfully' });
            } catch (err) {
                console.error('[metaAdsController] disconnectAccount error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Get Available Ad Accounts
         * GET /api/meta/ad-accounts
         */
        getAdAccounts: async (req, res) => {
            try {
                const accessToken = req.meta.accessToken;
                const adAccounts = await MetaAdsService.getAdAccounts(accessToken);
                return res.json({ success: true, data: adAccounts });
            } catch (err) {
                console.error('[metaAdsController] getAdAccounts error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Get Pages and connected Instagram accounts
         * GET /api/meta/pages
         */
        getPages: async (req, res) => {
            try {
                const accessToken = req.meta.accessToken;
                const pages = await MetaAdsService.getPages(accessToken);
                return res.json({ success: true, data: pages });
            } catch (err) {
                console.error('[metaAdsController] getPages error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Upload Ad Creative Image
         * POST /api/meta/creative/upload
         */
        uploadCreativeImage: async (req, res) => {
            try {
                const accessToken = req.meta.accessToken;
                const adAccountId = req.body.adAccountId || req.meta.adAccountId;

                if (!adAccountId) {
                    return res.status(400).json({ success: false, error: 'adAccountId is required' });
                }

                if (!req.file) {
                    return res.status(400).json({ success: false, error: 'Image file is required' });
                }

                const result = await MetaAdsService.uploadAdImage(accessToken, adAccountId, {
                    filePath: req.file.path,
                    fileName: req.file.originalname
                });

                return res.json({
                    success: true,
                    data: {
                        hash: result.hash,
                        url: result.url,
                        localPath: `/uploads/${req.file.filename}`
                    }
                });
            } catch (err) {
                console.error('[metaAdsController] uploadCreativeImage error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Create Full Campaign (Orchestrated Wizard Creation)
         * POST /api/meta/campaigns
         */
        createFullCampaign: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const accessToken = req.meta.accessToken;
                const pageAccessToken = req.meta.pageAccessToken;
                const payload = req.body;

                const adAccountId = payload.adAccountId || req.meta.adAccountId;
                const pageId = payload.identity?.pageId || req.meta.pageId;

                if (!adAccountId) {
                    return res.status(400).json({ success: false, error: 'No adAccountId configured' });
                }

                // 1. Create Campaign
                console.log(`[metaAdsController] Step 1: Creating campaign "${payload.name}"...`);
                const campaignRes = await MetaAdsService.createCampaign(accessToken, adAccountId, payload);
                const metaCampaignId = campaignRes.id;

                // 2. Create Ad Set
                console.log(`[metaAdsController] Step 2: Creating ad set for campaign ${metaCampaignId}...`);
                const adSetData = {
                    ...payload,
                    metaCampaignId
                };
                const adSetRes = await MetaAdsService.createAdSet(accessToken, adAccountId, adSetData);
                const metaAdSetId = adSetRes.id;

                // 3. Create Lead Form (if objective is LEADS and destination is ON_AD)
                let metaLeadFormId = null;
                if (payload.objective === 'OUTCOME_LEADS' && payload.destinationType === 'ON_AD' && payload.leadForm) {
                    console.log(`[metaAdsController] Step 3: Creating lead form for page ${pageId}...`);
                    try {
                        const leadFormRes = await MetaAdsService.createLeadForm(pageAccessToken, pageId, payload.leadForm);
                        metaLeadFormId = leadFormRes.id;
                    } catch (formErr) {
                        console.warn('[metaAdsController] Failed to create lead form on Meta, continuing:', formErr.message);
                    }
                }

                // 4. Create Ad Creative
                console.log(`[metaAdsController] Step 4: Creating ad creative...`);
                const creativeData = {
                    ...payload,
                    metaLeadFormId,
                    identity: {
                        pageId,
                        instagramAccountId: payload.identity?.instagramAccountId || req.meta.instagramActorId
                    }
                };
                const creativeRes = await MetaAdsService.createAdCreative(accessToken, adAccountId, creativeData);
                const metaCreativeId = creativeRes.id;

                // 5. Create Ad
                console.log(`[metaAdsController] Step 5: Creating ad...`);
                const adData = {
                    adName: payload.adName || `${payload.name} - Ad`,
                    metaAdSetId,
                    metaCreativeId,
                    status: payload.status || 'ACTIVE'
                };
                const adRes = await MetaAdsService.createAd(accessToken, adAccountId, adData);
                const metaAdId = adRes.id;

                // 6. Save in MongoDB
                const newCampaign = new MetaAdCampaign({
                    tenantId,
                    metaCampaignId,
                    metaAdSetId,
                    metaCreativeId,
                    metaAdId,
                    metaLeadFormId,
                    ...payload,
                    status: 'ACTIVE'
                });

                await newCampaign.save();

                return res.status(201).json({
                    success: true,
                    message: 'Campaign published successfully to Meta!',
                    data: newCampaign
                });
            } catch (err) {
                console.error('[metaAdsController] createFullCampaign error:', err);
                return res.status(500).json({
                    success: false,
                    error: err.message,
                    metaError: err.metaError || null
                });
            }
        },

        /**
         * List Campaigns for Tenant
         * GET /api/meta/campaigns
         */
        getCampaigns: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const { status, search, page = 1, limit = 20 } = req.query;

                const query = { tenantId };
                if (status && status !== 'ALL') {
                    query.status = status;
                }
                if (search) {
                    query.name = { $regex: search, $options: 'i' };
                }

                const skip = (parseInt(page) - 1) * parseInt(limit);
                const [campaigns, total] = await Promise.all([
                    MetaAdCampaign.find(query).sort({ createdAt: -1 }).skip(skip).limit(parseInt(limit)).lean(),
                    MetaAdCampaign.countDocuments(query)
                ]);

                return res.json({
                    success: true,
                    data: campaigns,
                    pagination: {
                        page: parseInt(page),
                        limit: parseInt(limit),
                        total,
                        pages: Math.ceil(total / parseInt(limit))
                    }
                });
            } catch (err) {
                console.error('[metaAdsController] getCampaigns error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Get Campaign by ID
         * GET /api/meta/campaigns/:id
         */
        getCampaignById: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const campaign = await MetaAdCampaign.findOne({ _id: req.params.id, tenantId });
                if (!campaign) {
                    return res.status(404).json({ success: false, error: 'Campaign not found' });
                }
                return res.json({ success: true, data: campaign });
            } catch (err) {
                console.error('[metaAdsController] getCampaignById error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Sync & Fetch Live Insights from Meta
         * GET /api/meta/campaigns/:id/stats
         */
        syncCampaignStats: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const campaign = await MetaAdCampaign.findOne({ _id: req.params.id, tenantId });
                if (!campaign) {
                    return res.status(404).json({ success: false, error: 'Campaign not found' });
                }

                if (campaign.metaCampaignId && req.meta?.accessToken) {
                    try {
                        const insights = await MetaAdsService.getCampaignInsights(
                            req.meta.accessToken,
                            campaign.metaCampaignId
                        );
                        campaign.insights = insights;
                        await campaign.save();
                    } catch (apiErr) {
                        console.warn('[metaAdsController] Sync insights error from Meta:', apiErr.message);
                    }
                }

                return res.json({ success: true, data: campaign.insights });
            } catch (err) {
                console.error('[metaAdsController] syncCampaignStats error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Update Campaign Status (Pause / Resume)
         * PATCH /api/meta/campaigns/:id/status
         */
        updateCampaignStatus: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const { status } = req.body; // 'ACTIVE' or 'PAUSED'
                if (!['ACTIVE', 'PAUSED'].includes(status)) {
                    return res.status(400).json({ success: false, error: 'Invalid status. Must be ACTIVE or PAUSED' });
                }

                const campaign = await MetaAdCampaign.findOne({ _id: req.params.id, tenantId });
                if (!campaign) {
                    return res.status(404).json({ success: false, error: 'Campaign not found' });
                }

                // Update on Meta
                if (campaign.metaCampaignId && req.meta?.accessToken) {
                    await MetaAdsService.updateCampaignStatus(req.meta.accessToken, campaign.metaCampaignId, status);
                }

                campaign.status = status;
                await campaign.save();

                return res.json({
                    success: true,
                    message: `Campaign ${status === 'ACTIVE' ? 'resumed' : 'paused'} successfully`,
                    data: campaign
                });
            } catch (err) {
                console.error('[metaAdsController] updateCampaignStatus error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Delete Campaign
         * DELETE /api/meta/campaigns/:id
         */
        deleteCampaign: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const campaign = await MetaAdCampaign.findOne({ _id: req.params.id, tenantId });
                if (!campaign) {
                    return res.status(404).json({ success: false, error: 'Campaign not found' });
                }

                if (campaign.metaCampaignId && req.meta?.accessToken) {
                    try {
                        await MetaAdsService.updateCampaignStatus(req.meta.accessToken, campaign.metaCampaignId, 'DELETED');
                    } catch (delErr) {
                        console.warn('[metaAdsController] Meta API delete campaign warning:', delErr.message);
                    }
                }

                campaign.status = 'DELETED';
                await campaign.save();

                return res.json({ success: true, message: 'Campaign deleted successfully' });
            } catch (err) {
                console.error('[metaAdsController] deleteCampaign error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        },

        /**
         * Get Leads Generated from Meta Ads
         * GET /api/meta/leads
         */
        getMetaLeads: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const { campaignId, page = 1, limit = 50 } = req.query;

                const query = {
                    tenantId,
                    source: 'meta_ads'
                };

                if (campaignId) {
                    query['metadata.metaCampaignId'] = campaignId;
                }

                const skip = (parseInt(page) - 1) * parseInt(limit);
                const [leads, total] = await Promise.all([
                    Lead.find(query).sort({ createdAt: -1 }).skip(skip).limit(parseInt(limit)).lean(),
                    Lead.countDocuments(query)
                ]);

                return res.json({
                    success: true,
                    data: leads,
                    pagination: {
                        page: parseInt(page),
                        limit: parseInt(limit),
                        total,
                        pages: Math.ceil(total / parseInt(limit))
                    }
                });
            } catch (err) {
                console.error('[metaAdsController] getMetaLeads error:', err);
                return res.status(500).json({ success: false, error: err.message });
            }
        }
    };
}

module.exports = { createMetaAdsController };
