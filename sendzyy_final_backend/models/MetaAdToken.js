'use strict';

const mongoose = require('mongoose');

const metaAdTokenSchema = new mongoose.Schema({
    tenantId: {
        type: String,
        required: true,
        unique: true,
        index: true
    },
    // AES-256-CBC encrypted token string (iv:hex)
    accessToken: {
        type: String,
        required: true
    },
    adAccountId: {
        type: String,
        default: null,
        index: true
    },
    adAccountName: {
        type: String,
        default: null
    },
    pageId: {
        type: String,
        default: null,
        index: true
    },
    pageName: {
        type: String,
        default: null
    },
    pageAccessToken: {
        type: String,
        default: null
    },
    businessId: {
        type: String,
        default: null
    },
    instagramActorId: {
        type: String,
        default: null
    },
    status: {
        type: String,
        enum: ['connected', 'disconnected', 'expired'],
        default: 'connected'
    },
    connectedAt: {
        type: Date,
        default: Date.now
    },
    expiresAt: {
        type: Date,
        default: null
    },
    updatedAt: {
        type: Date,
        default: Date.now
    }
}, { timestamps: true });

const MetaAdToken = mongoose.model('MetaAdToken', metaAdTokenSchema);

module.exports = MetaAdToken;
