'use strict';

const mongoose = require('mongoose');

const leadTriggerSchema = new mongoose.Schema({
  tenantId: { type: String, required: true },
  source: { 
    type: String, 
    enum: ['shopify', 'wordpress', 'indiamart', 'meta_ads', 'any'], 
    default: 'any' 
  },
  adType: { 
    type: String, 
    enum: ['instant_form', 'ctwa', 'any'], 
    default: 'any' 
  },
  formId: { type: String, default: '' },
  campaignId: { type: String, default: '' },
  adId: { type: String, default: '' },
  formName: { type: String, default: '' },
  action: { 
    type: String, 
    enum: ['send_template', 'start_chatbot'], 
    required: true 
  },
  templateName: { type: String, default: '' },
  templateLanguage: { type: String, default: 'en_US' },
  mediaId: { type: String, default: '' },
  mediaType: { type: String, default: '' },
  variableMapping: { type: mongoose.Schema.Types.Mixed, default: {} },
  chatbotId: { type: String, default: '' },
  cooldownDays: { type: Number, default: 7 },
  requireConsent: { type: Boolean, default: false },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

leadTriggerSchema.index({ tenantId: 1, source: 1, isActive: 1 });

module.exports = mongoose.models.LeadTrigger || mongoose.model('LeadTrigger', leadTriggerSchema);
