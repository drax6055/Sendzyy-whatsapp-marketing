'use strict';

const mongoose = require('mongoose');

const touchpointSchema = new mongoose.Schema({
  dedupeKey: { type: String, default: '' }, // matches MetaLeadEvent.dedupeKey
  source: { type: String, default: 'meta_ads' },
  adType: { type: String, enum: ['instant_form', 'ctwa', null], default: null },
  sourceType: { type: String, default: '' }, // CTWA referral source_type: ad | post
  platform: { type: String, enum: ['fb', 'ig', 'unknown'], default: 'unknown' },
  isOrganic: { type: Boolean, default: false },
  pageId: { type: String, default: '' },
  pageName: { type: String, default: '' },
  formId: { type: String, default: '' },
  formName: { type: String, default: '' },
  adId: { type: String, default: '' },
  adName: { type: String, default: '' },
  adsetId: { type: String, default: '' },
  adsetName: { type: String, default: '' },
  campaignId: { type: String, default: '' },
  campaignName: { type: String, default: '' },
  leadgenId: { type: String, default: '' },
  ctwaClid: { type: String, default: '' },
  headline: { type: String, default: '' },
  body: { type: String, default: '' },
  sourceUrl: { type: String, default: '' },
  consentQuestion: { type: String, default: '' },
  consentAnswer: { type: String, default: '' },
  consentRecordedAt: { type: Date },
  at: { type: Date, default: Date.now }
}, { _id: false });

const leadSchema = new mongoose.Schema({
  tenantId: { type: String, required: true },
  name: { type: String, default: '' },
  mobileNumber: { type: String, default: '' }, // Normalized E.164 without '+', optional if missing/invalid
  email: { type: String, default: '' },
  companyName: { type: String, default: '' },
  source: { 
    type: String, 
    enum: ['shopify', 'wordpress', 'indiamart', 'meta_ads'], 
    required: true 
  },
  adType: {
    type: String,
    enum: ['instant_form', 'ctwa', null],
    default: null
  },
  formName: { type: String, default: '' },
  touchpoints: [touchpointSchema],
  meta: { type: mongoose.Schema.Types.Mixed, default: {} }, // snapshot of latest Meta touchpoint for quick UI filters
  metadata: { type: mongoose.Schema.Types.Mixed, default: {} },
  needsAttention: { type: Boolean, default: false }, // flags missing/invalid phone numbers
  invalidPhoneRaw: { type: String, default: '' },
  optedOut: { type: Boolean, default: false },
  lastTemplateSentAt: { type: Date },
  status: { 
    type: String, 
    enum: ['new', 'contacted', 'engaged', 'converted', 'failed'], 
    default: 'new' 
  },
  clientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Client' },
  isDuplicate: { type: Boolean, default: false }
}, { timestamps: true });

leadSchema.index({ tenantId: 1, createdAt: -1 });
leadSchema.index({ tenantId: 1, mobileNumber: 1 });
leadSchema.index({ tenantId: 1, 'touchpoints.source': 1, 'touchpoints.adType': 1 });
leadSchema.index({ tenantId: 1, 'meta.formId': 1 });
leadSchema.index({ tenantId: 1, 'meta.campaignId': 1 });

module.exports = mongoose.models.Lead || mongoose.model('Lead', leadSchema);
