'use strict';

const mongoose = require('mongoose');

const metaLeadEventSchema = new mongoose.Schema({
  tenantId: { type: String, required: true },
  dedupeKey: { type: String, required: true }, // "lf:{leadgenId}" or "ctwa:{wamid}"
  type: { type: String, enum: ['instant_form', 'ctwa'], required: true },
  status: { 
    type: String, 
    enum: ['processing', 'lead_saved', 'done', 'failed'], 
    default: 'processing' 
  },
  leadId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lead' },
  pageId: { type: String, default: '' },
  formId: { type: String, default: '' },
  error: { type: String, default: '' },
  rawPayload: { type: mongoose.Schema.Types.Mixed, default: {} }
}, { timestamps: true });

metaLeadEventSchema.index({ tenantId: 1, dedupeKey: 1 }, { unique: true });
metaLeadEventSchema.index({ createdAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 90 }); // 90-day TTL

module.exports = mongoose.model('MetaLeadEvent', metaLeadEventSchema);
