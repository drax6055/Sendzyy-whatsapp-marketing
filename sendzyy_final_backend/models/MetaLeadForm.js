'use strict';

const mongoose = require('mongoose');

const metaLeadFormSchema = new mongoose.Schema({
  tenantId: { type: String, required: true },
  pageId: { type: String, required: true },
  formId: { type: String, required: true },
  name: { type: String, default: '' },
  status: { type: String, default: 'ACTIVE' }, // ACTIVE / ARCHIVED ...
  questions: { type: mongoose.Schema.Types.Mixed, default: [] },
  syncEnabled: { type: Boolean, default: true },
  lastSyncedAt: { type: Date }
}, { timestamps: true });

metaLeadFormSchema.index({ tenantId: 1, formId: 1 }, { unique: true });
metaLeadFormSchema.index({ tenantId: 1, pageId: 1 });

module.exports = mongoose.model('MetaLeadForm', metaLeadFormSchema);
