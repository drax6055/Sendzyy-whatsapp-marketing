'use strict';

const axios = require('axios');
const MetaAdCampaign = require('../models/MetaAdCampaign');
const MetaAdToken = require('../models/MetaAdToken');
const MetaAdsService = require('../services/MetaAdsService');
const { encryptSecret, decryptSecret } = require('../cryptoUtils');

function createMetaAdsController({ Lead, Tenant, triggerLeadAction }) {
    return {
        /**
         * Connect Facebook Business Account / Token
         * POST /api/meta/auth/connect
         * Supports: userAccessToken, OAuth code, or syncing from tenant onboarding
         */
        connectAccount: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                let {
                    userAccessToken,
                    code,
                    useTenantOnboarding,
                    adAccountId,
                    adAccountName,
                    pageId,
                    pageName,
                    instagramActorId,
                    businessId
                } = req.body;

                // 1. If useTenantOnboarding is requested or no token/code provided, sync from Tenant whatsappConfig
                if (useTenantOnboarding || (!userAccessToken && !code)) {
                    const tenant = await Tenant.findById(tenantId);
                    if (tenant?.whatsappConfig?.accessToken) {
                        userAccessToken = tenant.whatsappConfig.accessToken;
                        businessId = businessId || tenant.whatsappConfig.businessPortfolioId || tenant.whatsappConfig.businessId;
                        console.log(`[metaAdsController] Synced onboarding token for tenant ${tenantId}`);
                    } else if (!userAccessToken && !code) {
                        return res.status(400).json({
                            success: false,
                            error: 'No connected Meta account found in General Settings. Please connect via Facebook or provide a token.'
                        });
                    }
                }

                // 2. If OAuth code is provided, exchange for user access token
                if (code && (!userAccessToken || userAccessToken.trim() === '')) {
                    const appId = process.env.META_APP_ID || '1509853364110343';
                    const appSecret = process.env.META_APP_SECRET;
                    if (!appSecret) {
                        return res.status(500).json({
                            success: false,
                            error: 'META_APP_SECRET is not configured on the server environment.'
                        });
                    }
                    const apiVersion = process.env.META_API_VERSION || 'v25.0';
                    const tokenUrl = `https://graph.facebook.com/${apiVersion}/oauth/access_token`;
                    try {
                        const tokenRes = await axios.get(tokenUrl, {
                            params: {
                                client_id: appId,
                                client_secret: appSecret,
                                code: code.trim()
                            }
                        });
                        userAccessToken = tokenRes.data?.access_token;
                        console.log('[metaAdsController] Exchanged OAuth code for user access token');
                    } catch (codeErr) {
                        console.error('[metaAdsController] Code exchange error:', codeErr.response?.data || codeErr.message);
                        return res.status(400).json({
                            success: false,
                            error: 'Failed to exchange Facebook authorization code: ' + (codeErr.response?.data?.error?.message || codeErr.message)
                        });
                    }
                }

                if (!userAccessToken) {
                    return res.status(400).json({ success: false, error: 'User access token or OAuth code is required' });
                }

                // 3. Exchange for long-lived user token (~60 days)
                let longLivedToken = userAccessToken;
                let expiresAt = null;
                try {
                    const tokenExchange = await MetaAdsService.exchangeForLongLivedToken(userAccessToken);
                    longLivedToken = tokenExchange.accessToken;
                    expiresAt = tokenExchange.expiresAt;
                } catch (tokenErr) {
                    console.warn('[metaAdsController] Token exchange warning:', tokenErr.message);
                }

                // 4. Auto-fetch available Ad Accounts and Pages
                let adAccounts = [];
                let pages = [];
                try {
                    adAccounts = await MetaAdsService.getAdAccounts(longLivedToken);
                } catch (adErr) {
                    console.warn('[metaAdsController] Auto-fetch ad accounts warning:', adErr.message);
                }
                try {
                    pages = await MetaAdsService.getPages(longLivedToken);
                } catch (pageErr) {
                    console.warn('[metaAdsController] Auto-fetch pages warning:', pageErr.message);
                }

                // Auto-select if single account / page available and not specified
                if (!adAccountId && adAccounts.length > 0) {
                    adAccountId = adAccounts[0].id;
                    adAccountName = adAccounts[0].name;
                }
                if (!pageId && pages.length > 0) {
                    pageId = pages[0].id;
                    pageName = pages[0].name;
                }

                // 5. If pageId was resolved, fetch page access token and subscribe webhook
                let pageAccessToken = null;
                if (pageId && pages.length > 0) {
                    const targetPage = pages.find(p => p.id === pageId);
                    if (targetPage && targetPage.access_token) {
                        pageAccessToken = targetPage.access_token;
                        try {
                            await MetaAdsService.subscribePageLeadWebhook(pageAccessToken, pageId);
                            console.log(`[metaAdsController] Subscribed page ${pageId} to leadgen webhook`);
                        } catch (subErr) {
                            console.warn('[metaAdsController] Webhook subscription warning:', subErr.message);
                        }
                    }
                }

                // 6. Encrypt secrets before storing in DB
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
                    },
                    adAccounts,
                    pages
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

                let hasTenantOnboarding = false;
                let tenantBusinessId = null;
                try {
                    const tenant = await Tenant.findById(tenantId).select('whatsappConfig').lean();
                    hasTenantOnboarding = !!(tenant?.whatsappConfig?.accessToken && tenant?.whatsappConfig?.accessToken.trim());
                    tenantBusinessId = tenant?.whatsappConfig?.businessPortfolioId || tenant?.whatsappConfig?.businessAccountId || null;
                } catch (tErr) {
                    console.warn('[metaAdsController] Tenant lookup warning:', tErr.message);
                }

                if (!tokenDoc || tokenDoc.status !== 'connected') {
                    return res.json({
                        success: true,
                        connected: false,
                        status: tokenDoc ? tokenDoc.status : 'disconnected',
                        hasTenantOnboarding,
                        tenantBusinessId
                    });
                }

                return res.json({
                    success: true,
                    connected: true,
                    hasTenantOnboarding,
                    tenantBusinessId,
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
         * Select Active Ad Account & Facebook Page
         * POST /api/meta/auth/select-assets
         */
        selectAssets: async (req, res) => {
            try {
                const tenantId = req.user?.tenantId || req.user?.id;
                const { adAccountId, adAccountName, pageId, pageName } = req.body;
                const tokenDoc = await MetaAdToken.findOne({ tenantId, status: 'connected' });
                if (!tokenDoc) {
                    return res.status(400).json({ success: false, error: 'Meta account not connected' });
                }

                let pageAccessToken = tokenDoc.pageAccessToken;
                if (pageId) {
                    try {
                        const userToken = decryptSecret(tokenDoc.accessToken);
                        const pages = await MetaAdsService.getPages(userToken);
                        const targetPage = pages.find(p => p.id === pageId);
                        if (targetPage && targetPage.access_token) {
                            pageAccessToken = encryptSecret(targetPage.access_token);
                            try {
                                await MetaAdsService.subscribePageLeadWebhook(targetPage.access_token, pageId);
                                console.log(`[metaAdsController] Subscribed page ${pageId} to leadgen webhook`);
                            } catch (subErr) {
                                console.warn('[metaAdsController] Webhook subscription warning:', subErr.message);
                            }
                        }
                    } catch (err) {
                        console.warn('[metaAdsController] selectAssets page retrieval warning:', err.message);
                    }
                }

                if (adAccountId !== undefined) tokenDoc.adAccountId = adAccountId;
                if (adAccountName !== undefined) tokenDoc.adAccountName = adAccountName;
                if (pageId !== undefined) tokenDoc.pageId = pageId;
                if (pageName !== undefined) tokenDoc.pageName = pageName;
                if (pageAccessToken !== undefined) tokenDoc.pageAccessToken = pageAccessToken;
                await tokenDoc.save();

                return res.json({
                    success: true,
                    message: 'Active Ad Account and Facebook Page updated successfully',
                    data: {
                        adAccountId: tokenDoc.adAccountId,
                        adAccountName: tokenDoc.adAccountName,
                        pageId: tokenDoc.pageId,
                        pageName: tokenDoc.pageName
                    }
                });
            } catch (err) {
                console.error('[metaAdsController] selectAssets error:', err);
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
