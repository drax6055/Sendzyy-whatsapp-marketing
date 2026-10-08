'use strict';

const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

const GRAPH_VERSION = process.env.META_API_VERSION || 'v21.0';
const GRAPH_BASE = `https://graph.facebook.com/${GRAPH_VERSION}`;

class MetaAdsService {
    /**
     * Helper to make authenticated requests to Graph API
     */
    static async _request(method, endpoint, params = {}, data = null, headers = {}) {
        try {
            const url = endpoint.startsWith('http') ? endpoint : `${GRAPH_BASE}/${endpoint.replace(/^\//, '')}`;
            const response = await axios({
                method,
                url,
                params,
                data,
                headers: {
                    'Content-Type': 'application/json',
                    ...headers
                },
                timeout: 30000
            });
            return response.data;
        } catch (error) {
            const errData = error.response?.data?.error || error.response?.data || error.message;
            console.error(`[MetaAdsService] Graph API error on ${method} ${endpoint}:`, errData);
            const err = new Error(errData.message || (typeof errData === 'string' ? errData : JSON.stringify(errData)));
            err.metaError = errData;
            err.statusCode = error.response?.status || 500;
            throw err;
        }
    }

    /**
     * Exchange short-lived User token for long-lived User Access Token (~60 days)
     */
    static async exchangeForLongLivedToken(shortLivedToken) {
        const appId = process.env.META_APP_ID;
        const appSecret = process.env.META_APP_SECRET;

        if (!appId || !appSecret) {
            throw new Error('META_APP_ID or META_APP_SECRET missing in backend environment');
        }

        const data = await this._request('GET', '/oauth/access_token', {
            grant_type: 'fb_exchange_token',
            client_id: appId,
            client_secret: appSecret,
            fb_exchange_token: shortLivedToken
        });

        // data contains: { access_token: "...", token_type: "bearer", expires_in: 5184000 }
        return {
            accessToken: data.access_token,
            expiresIn: data.expires_in,
            expiresAt: data.expires_in ? new Date(Date.now() + data.expires_in * 1000) : null
        };
    }

    /**
     * Get Ad Accounts that the authenticated user can manage
     */
    static async getAdAccounts(accessToken) {
        const fields = 'id,name,account_id,account_status,currency,timezone_name,balance,amount_spent,business{id,name}';
        const res = await this._request('GET', '/me/adaccounts', {
            fields,
            access_token: accessToken,
            limit: 50
        });
        return res.data || [];
    }

    /**
     * Get Pages associated with user + their Page Access Tokens and linked Instagram accounts
     */
    static async getPages(accessToken) {
        const fields = 'id,name,access_token,category,instagram_business_account{id,username,name,profile_picture_url},tasks';
        const res = await this._request('GET', '/me/accounts', {
            fields,
            access_token: accessToken,
            limit: 50
        });
        return res.data || [];
    }

    /**
     * Create Meta Campaign (Step 1)
     */
    static async createCampaign(accessToken, adAccountId, campaignData) {
        const cleanAdAccountId = adAccountId.startsWith('act_') ? adAccountId : `act_${adAccountId}`;
        
        const payload = {
            name: campaignData.name,
            objective: campaignData.objective || 'OUTCOME_LEADS',
            status: campaignData.status || 'ACTIVE',
            special_ad_categories: campaignData.specialAdCategories && campaignData.specialAdCategories.length > 0
                ? campaignData.specialAdCategories
                : ['NONE'],
            buying_type: campaignData.buyingType || 'AUCTION',
            access_token: accessToken
        };

        if (campaignData.specialAdCategoryCountries && campaignData.specialAdCategoryCountries.length > 0) {
            payload.special_ad_category_country = campaignData.specialAdCategoryCountries;
        }

        // Advantage+ Campaign Budget
        if (campaignData.advantageCampaignBudget && campaignData.campaignBudget?.amount) {
            if (campaignData.campaignBudget.type === 'lifetime') {
                payload.lifetime_budget = campaignData.campaignBudget.amount;
            } else {
                payload.daily_budget = campaignData.campaignBudget.amount;
            }
            if (campaignData.campaignBidStrategy) {
                payload.bid_strategy = campaignData.campaignBidStrategy;
            }
        }

        const res = await this._request('POST', `/${cleanAdAccountId}/campaigns`, {}, payload);
        return res; // returns { id: "campaign_id" }
    }

    /**
     * Create Meta Ad Set (Step 2)
     */
    static async createAdSet(accessToken, adAccountId, adSetData) {
        const cleanAdAccountId = adAccountId.startsWith('act_') ? adAccountId : `act_${adAccountId}`;

        const payload = {
            name: adSetData.adSetName || `${adSetData.name} - AdSet`,
            campaign_id: adSetData.metaCampaignId,
            optimization_goal: adSetData.optimizationGoal || 'LEAD_GENERATION',
            billing_event: adSetData.billingEvent || 'IMPRESSIONS',
            status: adSetData.status || 'ACTIVE',
            access_token: accessToken
        };

        // Budget if not Advantage+ at Campaign level
        if (!adSetData.advantageCampaignBudget && adSetData.adSetBudget?.amount) {
            if (adSetData.adSetBudget.type === 'lifetime') {
                payload.lifetime_budget = adSetData.adSetBudget.amount;
            } else {
                payload.daily_budget = adSetData.adSetBudget.amount;
            }
        }

        // Schedule
        if (adSetData.schedule?.startTime) {
            payload.start_time = new Date(adSetData.schedule.startTime).toISOString();
        }
        if (adSetData.schedule?.endTime && !adSetData.schedule?.runContinuously) {
            payload.end_time = new Date(adSetData.schedule.endTime).toISOString();
        }

        // Bid Strategy
        if (adSetData.bidStrategy) {
            payload.bid_strategy = adSetData.bidStrategy;
        }
        if (adSetData.bidAmount) {
            payload.bid_amount = adSetData.bidAmount;
        }

        // Destination & Promoted Object
        if (adSetData.destinationType) {
            payload.destination_type = adSetData.destinationType;
        }
        if (adSetData.promotedObject && Object.keys(adSetData.promotedObject).length > 0) {
            const po = {};
            if (adSetData.promotedObject.pageId) po.page_id = adSetData.promotedObject.pageId;
            if (adSetData.promotedObject.pixelId) po.pixel_id = adSetData.promotedObject.pixelId;
            if (adSetData.promotedObject.customEventType) po.custom_event_type = adSetData.promotedObject.customEventType;
            if (adSetData.promotedObject.applicationId) po.application_id = adSetData.promotedObject.applicationId;
            if (adSetData.promotedObject.objectStoreUrl) po.object_store_url = adSetData.promotedObject.objectStoreUrl;
            if (adSetData.promotedObject.productSetId) po.product_set_id = adSetData.promotedObject.productSetId;
            if (Object.keys(po).length > 0) {
                payload.promoted_object = po;
            }
        }

        // Build Targeting
        const targeting = {};

        // Locations
        if (adSetData.targeting?.locations && adSetData.targeting.locations.length > 0) {
            const countries = [];
            const cities = [];
            const regions = [];

            for (const loc of adSetData.targeting.locations) {
                if (loc.type === 'country' || !loc.type) {
                    countries.push(loc.countryCode || loc.key || 'IN');
                } else if (loc.type === 'city') {
                    cities.push({ key: loc.key, radius: loc.radius || 25, distance_unit: loc.distanceUnit || 'kilometer' });
                } else if (loc.type === 'region') {
                    regions.push({ key: loc.key });
                }
            }

            targeting.geo_locations = {
                location_types: [adSetData.targeting.locationType || 'home_or_recent'],
                countries: countries.length > 0 ? countries : ['IN']
            };
            if (cities.length > 0) targeting.geo_locations.cities = cities;
            if (regions.length > 0) targeting.geo_locations.regions = regions;
        } else {
            targeting.geo_locations = {
                location_types: ['home_or_recent'],
                countries: ['IN']
            };
        }

        // Age & Gender
        if (adSetData.targeting?.ageMin) targeting.age_min = adSetData.targeting.ageMin;
        if (adSetData.targeting?.ageMax) targeting.age_max = adSetData.targeting.ageMax;
        if (adSetData.targeting?.gender) {
            if (adSetData.targeting.gender === 'MALE') targeting.genders = [1];
            else if (adSetData.targeting.gender === 'FEMALE') targeting.genders = [2];
            // ALL leaves genders undefined
        }

        // Interests & Behaviors
        const flexibleSpec = [];
        if (adSetData.targeting?.interests && adSetData.targeting.interests.length > 0) {
            flexibleSpec.push({
                interests: adSetData.targeting.interests.map(i => ({ id: i.id, name: i.name }))
            });
        }
        if (adSetData.targeting?.behaviors && adSetData.targeting.behaviors.length > 0) {
            flexibleSpec.push({
                behaviors: adSetData.targeting.behaviors.map(b => ({ id: b.id, name: b.name }))
            });
        }
        if (flexibleSpec.length > 0) {
            targeting.flexible_spec = flexibleSpec;
        }

        // Placements
        if (adSetData.placements?.placementType === 'manual') {
            if (adSetData.placements.platforms) {
                targeting.publisher_platforms = adSetData.placements.platforms;
            }
            if (adSetData.placements.facebookPositions?.length > 0) {
                targeting.facebook_positions = adSetData.placements.facebookPositions;
            }
            if (adSetData.placements.instagramPositions?.length > 0) {
                targeting.instagram_positions = adSetData.placements.instagramPositions;
            }
            if (adSetData.placements.devicePlatforms?.length > 0) {
                targeting.device_platforms = adSetData.placements.devicePlatforms;
            }
        }

        payload.targeting = targeting;

        const res = await this._request('POST', `/${cleanAdAccountId}/adsets`, {}, payload);
        return res; // returns { id: "adset_id" }
    }

    /**
     * Create Meta Leadgen Instant Form (Step 3B)
     */
    static async createLeadForm(pageAccessToken, pageId, formData) {
        // Map questions to Meta lead form questions array
        const questions = (formData.questions || []).map((q, idx) => {
            const metaQ = {
                type: q.type || 'FULL_NAME'
            };
            if (q.key) metaQ.key = q.key;
            if (q.label) metaQ.label = q.label;
            if (q.type === 'CUSTOM_MULTIPLE_CHOICE' && q.options) {
                metaQ.type = 'CUSTOM';
                metaQ.options = q.options.map(opt => ({ key: opt, value: opt }));
            } else if (q.type === 'CUSTOM_SHORT_ANSWER') {
                metaQ.type = 'CUSTOM';
            }
            return metaQ;
        });

        // Ensure default contact info fields exist if empty
        if (questions.length === 0) {
            questions.push({ type: 'FULL_NAME', label: 'Full name' });
            questions.push({ type: 'PHONE', label: 'Phone number' });
            questions.push({ type: 'EMAIL', label: 'Email' });
        }

        const payload = {
            name: formData.formName || `Lead Form ${Date.now()}`,
            questions: JSON.stringify(questions),
            privacy_policy: JSON.stringify({
                url: formData.privacyPolicy?.url || 'https://sendzyy.com/privacy',
                link_text: formData.privacyPolicy?.linkText || 'Privacy Policy'
            }),
            follow_up_action_url: formData.completion?.ctaUrl || 'https://sendzyy.com',
            thank_you_page: JSON.stringify({
                title: formData.completion?.headline || 'Thank you!',
                body: formData.completion?.description || 'We will reach out to you on WhatsApp shortly.',
                button_type: formData.completion?.ctaType || 'VIEW_WEBSITE',
                button_text: formData.completion?.ctaText || 'Visit Website',
                website_url: formData.completion?.ctaUrl || 'https://sendzyy.com',
                phone_number: formData.completion?.phoneNumber || ''
            }),
            access_token: pageAccessToken
        };

        const res = await this._request('POST', `/${pageId}/leadgen_forms`, {}, payload);
        return res; // returns { id: "lead_form_id" }
    }

    /**
     * Upload Image to Ad Account (Returns image hash)
     */
    static async uploadAdImage(accessToken, adAccountId, { filePath, imageBuffer, fileName }) {
        const cleanAdAccountId = adAccountId.startsWith('act_') ? adAccountId : `act_${adAccountId}`;
        const form = new FormData();
        form.append('access_token', accessToken);

        if (filePath && fs.existsSync(filePath)) {
            form.append('filename', fs.createReadStream(filePath));
        } else if (imageBuffer) {
            form.append('bytes', imageBuffer, { filename: fileName || 'ad_image.jpg' });
        } else {
            throw new Error('No image file or buffer provided for upload');
        }

        const response = await axios.post(
            `${GRAPH_BASE}/${cleanAdAccountId}/adimages`,
            form,
            {
                headers: form.getHeaders(),
                timeout: 60000
            }
        );

        // response.data.images[filename].hash
        const images = response.data?.images || {};
        const firstKey = Object.keys(images)[0];
        const imageData = images[firstKey] || {};

        return {
            hash: imageData.hash,
            url: imageData.url
        };
    }

    /**
     * Create Ad Creative (Step 3)
     */
    static async createAdCreative(accessToken, adAccountId, creativeData) {
        const cleanAdAccountId = adAccountId.startsWith('act_') ? adAccountId : `act_${adAccountId}`;

        const linkData = {
            message: creativeData.creative?.primaryText || '',
            name: creativeData.creative?.headline || '',
            description: creativeData.creative?.description || '',
            link: creativeData.creative?.websiteUrl || 'https://sendzyy.com'
        };

        if (creativeData.creative?.imageHash) {
            linkData.image_hash = creativeData.creative.imageHash;
        }

        // Call to action button
        const ctaType = creativeData.creative?.callToAction || 'LEARN_MORE';
        if (ctaType !== 'NO_BUTTON') {
            const ctaValue = {};
            if (creativeData.metaLeadFormId) {
                ctaValue.lead_gen_form_id = creativeData.metaLeadFormId;
            } else if (creativeData.creative?.websiteUrl) {
                ctaValue.link = creativeData.creative.websiteUrl;
            }
            linkData.call_to_action = {
                type: ctaType,
                value: ctaValue
            };
        }

        const objectStorySpec = {
            page_id: creativeData.identity?.pageId
        };
        if (creativeData.identity?.instagramAccountId) {
            objectStorySpec.instagram_actor_id = creativeData.identity.instagramAccountId;
        }
        objectStorySpec.link_data = linkData;

        const payload = {
            name: creativeData.adName || `Creative ${Date.now()}`,
            object_story_spec: objectStorySpec,
            access_token: accessToken
        };

        const res = await this._request('POST', `/${cleanAdAccountId}/adcreatives`, {}, payload);
        return res; // returns { id: "creative_id" }
    }

    /**
     * Create Meta Ad (Final publishing step)
     */
    static async createAd(accessToken, adAccountId, adData) {
        const cleanAdAccountId = adAccountId.startsWith('act_') ? adAccountId : `act_${adAccountId}`;

        const payload = {
            name: adData.adName || `Ad ${Date.now()}`,
            adset_id: adData.metaAdSetId,
            creative: { creative_id: adData.metaCreativeId },
            status: adData.status || 'ACTIVE',
            access_token: accessToken
        };

        const res = await this._request('POST', `/${cleanAdAccountId}/ads`, {}, payload);
        return res; // returns { id: "ad_id" }
    }

    /**
     * Update Campaign Status (ACTIVE, PAUSED, DELETED)
     */
    static async updateCampaignStatus(accessToken, campaignId, status) {
        const res = await this._request('POST', `/${campaignId}`, {}, {
            status: status,
            access_token: accessToken
        });
        return res;
    }

    /**
     * Fetch Campaign Insights
     */
    static async getCampaignInsights(accessToken, campaignId) {
        const fields = 'spend,reach,impressions,clicks,cpc,cpm,ctr,actions,cost_per_action_type';
        const res = await this._request('GET', `/${campaignId}/insights`, {
            fields,
            date_preset: 'maximum',
            access_token: accessToken
        });

        const row = res.data && res.data.length > 0 ? res.data[0] : null;
        if (!row) {
            return {
                spend: 0,
                reach: 0,
                impressions: 0,
                clicks: 0,
                cpc: 0,
                cpm: 0,
                ctr: 0,
                leadsCount: 0,
                cpl: 0,
                lastSyncedAt: new Date()
            };
        }

        // Find leads action count
        let leadsCount = 0;
        if (Array.isArray(row.actions)) {
            const leadAction = row.actions.find(a => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped');
            if (leadAction) leadsCount = Number(leadAction.value) || 0;
        }

        // Find cost per lead
        let cpl = 0;
        if (Array.isArray(row.cost_per_action_type)) {
            const cplAction = row.cost_per_action_type.find(a => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped');
            if (cplAction) cpl = Number(cplAction.value) || 0;
        }

        return {
            spend: Number(row.spend) || 0,
            reach: Number(row.reach) || 0,
            impressions: Number(row.impressions) || 0,
            clicks: Number(row.clicks) || 0,
            cpc: Number(row.cpc) || 0,
            cpm: Number(row.cpm) || 0,
            ctr: Number(row.ctr) || 0,
            leadsCount,
            cpl,
            lastSyncedAt: new Date()
        };
    }

    /**
     * Fetch Single Lead Data by leadgen_id
     */
    static async getLeadDetails(pageAccessToken, leadgenId) {
        const res = await this._request('GET', `/${leadgenId}`, {
            fields: 'id,created_time,field_data,form_id,ad_id,adset_id,campaign_id,page_id',
            access_token: pageAccessToken
        });
        return res;
    }

    /**
     * Subscribe Facebook Page to send 'leadgen' webhook events to the app
     */
    static async subscribePageLeadWebhook(pageAccessToken, pageId) {
        const res = await this._request('POST', `/${pageId}/subscribed_apps`, {}, {
            subscribed_fields: ['leadgen'],
            access_token: pageAccessToken
        });
        return res;
    }
}

module.exports = MetaAdsService;
