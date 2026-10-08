'use strict';

const mongoose = require('mongoose');

const metaAdCampaignSchema = new mongoose.Schema({
    tenantId: {
        type: String,
        required: true,
        index: true
    },
    // Meta platform IDs
    metaCampaignId: {
        type: String,
        index: true,
        sparse: true
    },
    metaAdSetId: {
        type: String,
        index: true,
        sparse: true
    },
    metaCreativeId: {
        type: String,
        sparse: true
    },
    metaAdId: {
        type: String,
        index: true,
        sparse: true
    },
    metaLeadFormId: {
        type: String,
        index: true,
        sparse: true
    },

    // ──────────────── STEP 1: CAMPAIGN LEVEL ────────────────
    name: {
        type: String,
        required: true,
        trim: true
    },
    specialAdCategories: {
        type: [String],
        enum: ['NONE', 'HOUSING', 'EMPLOYMENT', 'FINANCIAL_PRODUCTS_SERVICES', 'CREDIT', 'SOCIAL_ISSUES_ELECTIONS_POLITICS'],
        default: ['NONE']
    },
    specialAdCategoryCountries: {
        type: [String],
        default: []
    },
    objective: {
        type: String,
        required: true,
        enum: [
            'OUTCOME_AWARENESS',
            'OUTCOME_TRAFFIC',
            'OUTCOME_ENGAGEMENT',
            'OUTCOME_LEADS',
            'OUTCOME_APP_PROMOTION',
            'OUTCOME_SALES'
        ],
        default: 'OUTCOME_LEADS'
    },
    buyingType: {
        type: String,
        default: 'AUCTION'
    },
    advantageCampaignBudget: {
        type: Boolean,
        default: false
    },
    campaignBudget: {
        type: {
            type: String,
            enum: ['daily', 'lifetime'],
            default: 'daily'
        },
        amount: { type: Number, default: 0 }, // In currency subunits (paise for INR / cents for USD)
        currency: { type: String, default: 'INR' }
    },
    campaignBidStrategy: {
        type: String,
        enum: ['LOWEST_COST_WITHOUT_CAP', 'COST_CAP', 'LOWEST_COST_WITH_BID_CAP', 'LOWEST_COST_WITH_MIN_ROAS'],
        default: 'LOWEST_COST_WITHOUT_CAP'
    },
    isAbTest: {
        type: Boolean,
        default: false
    },

    // ──────────────── STEP 2: AD SET LEVEL ────────────────
    adSetName: {
        type: String,
        default: ''
    },
    optimizationGoal: {
        type: String,
        default: 'LEAD_GENERATION'
    },
    destinationType: {
        type: String,
        enum: ['ON_AD', 'WEBSITE', 'WHATSAPP', 'MESSENGER', 'PHONE_CALL', 'APP', 'INSTAGRAM_PROFILE', 'FACEBOOK_PAGE'],
        default: 'ON_AD'
    },
    billingEvent: {
        type: String,
        default: 'IMPRESSIONS'
    },
    promotedObject: {
        pageId: String,
        pixelId: String,
        customEventType: String,
        applicationId: String,
        objectStoreUrl: String,
        productSetId: String,
        leadGenFormId: String
    },
    adSetBudget: {
        type: {
            type: String,
            enum: ['daily', 'lifetime'],
            default: 'daily'
        },
        amount: { type: Number, default: 50000 }, // e.g. 50000 paise = ₹500
        currency: { type: String, default: 'INR' }
    },
    bidStrategy: {
        type: String,
        default: 'LOWEST_COST_WITHOUT_CAP'
    },
    bidAmount: {
        type: Number,
        default: null
    },
    schedule: {
        startTime: { type: Date, default: Date.now },
        endTime: { type: Date, default: null },
        runContinuously: { type: Boolean, default: true }
    },
    targeting: {
        audienceType: {
            type: String,
            enum: ['advantage_plus', 'manual'],
            default: 'advantage_plus'
        },
        customAudiences: [{ id: String, name: String }],
        excludedCustomAudiences: [{ id: String, name: String }],
        locations: [{
            type: { type: String, default: 'country' },
            name: { type: String, default: 'India' },
            key: { type: String, default: 'IN' },
            countryCode: { type: String, default: 'IN' },
            radius: { type: Number, default: 0 },
            distanceUnit: { type: String, default: 'kilometer' }
        }],
        locationType: {
            type: String,
            enum: ['home_or_recent', 'recent', 'home', 'travel_in'],
            default: 'home_or_recent'
        },
        ageMin: { type: Number, default: 18, min: 18, max: 65 },
        ageMax: { type: Number, default: 65, min: 18, max: 65 },
        gender: {
            type: String,
            enum: ['ALL', 'MALE', 'FEMALE'],
            default: 'ALL'
        },
        languages: [{ type: String }],
        interests: [{
            id: { type: String },
            name: { type: String }
        }],
        behaviors: [{
            id: { type: String },
            name: { type: String }
        }],
        demographics: [{
            id: { type: String },
            name: { type: String }
        }],
        targetingExpansion: { type: Boolean, default: true }
    },
    placements: {
        placementType: {
            type: String,
            enum: ['advantage_plus', 'manual'],
            default: 'advantage_plus'
        },
        platforms: {
            type: [String],
            default: ['facebook', 'instagram']
        },
        facebookPositions: {
            type: [String],
            default: ['feed', 'story', 'facebook_reels']
        },
        instagramPositions: {
            type: [String],
            default: ['stream', 'story', 'reels', 'explore']
        },
        messengerPositions: {
            type: [String],
            default: ['messenger_home', 'story']
        },
        audienceNetworkPositions: {
            type: [String],
            default: ['classic']
        },
        devicePlatforms: {
            type: [String],
            default: ['mobile', 'desktop']
        }
    },

    // ──────────────── STEP 3: CREATIVE & AD LEVEL ────────────────
    adName: {
        type: String,
        default: ''
    },
    identity: {
        pageId: { type: String, default: null },
        instagramAccountId: { type: String, default: null }
    },
    format: {
        type: String,
        enum: ['SINGLE_IMAGE', 'SINGLE_VIDEO', 'CAROUSEL', 'COLLECTION'],
        default: 'SINGLE_IMAGE'
    },
    creative: {
        headline: { type: String, default: '' },
        headlineVariants: [{ type: String }],
        primaryText: { type: String, default: '' },
        primaryTextVariants: [{ type: String }],
        description: { type: String, default: '' },
        descriptionVariants: [{ type: String }],
        callToAction: {
            type: String,
            enum: [
                'NO_BUTTON', 'LEARN_MORE', 'SIGN_UP', 'GET_QUOTE', 'APPLY_NOW',
                'DOWNLOAD', 'BOOK_NOW', 'CONTACT_US', 'SHOP_NOW', 'WATCH_MORE',
                'GET_OFFER', 'GET_SHOWTIMES', 'LISTEN_NOW', 'ORDER_NOW', 'SEE_MENU',
                'REQUEST_TIME', 'SUBSCRIBE', 'WHATSAPP_MESSAGE', 'CALL_NOW',
                'MESSAGE_PAGE', 'LIKE_PAGE', 'FOLLOW_PAGE', 'INSTALL_MOBILE_APP', 'USE_MOBILE_APP'
            ],
            default: 'LEARN_MORE'
        },
        websiteUrl: { type: String, default: '' },
        displayUrl: { type: String, default: '' },
        urlParameters: { type: String, default: '' },
        imageUrl: { type: String, default: '' },
        imageHash: { type: String, default: '' },
        videoUrl: { type: String, default: '' },
        videoId: { type: String, default: '' },
        carouselCards: [{
            imageUrl: String,
            imageHash: String,
            headline: String,
            description: String,
            linkUrl: String,
            callToAction: String
        }],
        advantageCreative: {
            brightnessContrast: { type: Boolean, default: true },
            visualTouchUps: { type: Boolean, default: true },
            music: { type: Boolean, default: false },
            comments: { type: Boolean, default: true }
        }
    },

    // ──────────────── STEP 3B: LEAD FORM BUILDER ────────────────
    leadForm: {
        formName: { type: String, default: '' },
        formType: {
            type: String,
            enum: ['MORE_VOLUME', 'HIGHER_INTENT', 'RICH_CREATIVE'],
            default: 'MORE_VOLUME'
        },
        language: { type: String, default: 'en_US' },
        intro: {
            headline: { type: String, default: '' },
            description: { type: String, default: '' }
        },
        questions: [{
            type: {
                type: String,
                enum: [
                    'FULL_NAME', 'FIRST_NAME', 'LAST_NAME', 'PHONE', 'EMAIL',
                    'CITY', 'STREET_ADDRESS', 'ZIP', 'STATE', 'COUNTRY',
                    'COMPANY_NAME', 'JOB_TITLE', 'WORK_EMAIL', 'WORK_PHONE_NUMBER',
                    'DOB', 'GENDER', 'CUSTOM_SHORT_ANSWER', 'CUSTOM_MULTIPLE_CHOICE'
                ],
                default: 'FULL_NAME'
            },
            key: { type: String },
            label: { type: String },
            options: [{ type: String }] // For MULTIPLE_CHOICE
        }],
        privacyPolicy: {
            url: { type: String, default: '' },
            linkText: { type: String, default: 'Privacy Policy' }
        },
        completion: {
            headline: { type: String, default: 'Thank You! We received your details.' },
            description: { type: String, default: 'Our team will reach out to you shortly via WhatsApp.' },
            ctaType: {
                type: String,
                enum: ['VIEW_WEBSITE', 'CALL_BUSINESS', 'VIEW_INSTAGRAM', 'SEND_WHATSAPP'],
                default: 'SEND_WHATSAPP'
            },
            ctaText: { type: String, default: 'Chat on WhatsApp' },
            ctaUrl: { type: String, default: '' },
            phoneNumber: { type: String, default: '' }
        }
    },

    // ──────────────── STATUS & LIFECYCLE ────────────────
    status: {
        type: String,
        enum: ['ACTIVE', 'PAUSED', 'DELETED', 'ARCHIVED', 'DRAFT', 'PENDING_REVIEW'],
        default: 'ACTIVE',
        index: true
    },
    effectiveStatus: {
        type: String,
        default: 'ACTIVE'
    },

    // ──────────────── ANALYTICS & INSIGHTS ────────────────
    insights: {
        spend: { type: Number, default: 0 },
        reach: { type: Number, default: 0 },
        impressions: { type: Number, default: 0 },
        clicks: { type: Number, default: 0 },
        cpc: { type: Number, default: 0 },
        cpm: { type: Number, default: 0 },
        ctr: { type: Number, default: 0 },
        leadsCount: { type: Number, default: 0 },
        cpl: { type: Number, default: 0 },
        lastSyncedAt: { type: Date, default: null }
    },

    // Auto-trigger WhatsApp Chatbot on new Lead
    autoTriggerChatbot: {
        type: Boolean,
        default: true
    },
    chatbotId: {
        type: String,
        default: null
    }
}, { timestamps: true });

// Compound index for fast tenant query listing
metaAdCampaignSchema.index({ tenantId: 1, createdAt: -1 });

const MetaAdCampaign = mongoose.model('MetaAdCampaign', metaAdCampaignSchema);

module.exports = MetaAdCampaign;
