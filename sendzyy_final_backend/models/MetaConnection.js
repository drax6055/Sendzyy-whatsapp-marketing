'use strict';

const mongoose = require('mongoose');

const metaConnectionSchema = new mongoose.Schema({
  tenantId: { type: String, required: true, index: true },
  fbUserId: { type: String, required: true },
  fbUserName: { type: String, default: '' },
  userAccessToken: { type: String, required: true },   // AES-256-GCM encrypted
  tokenExpiresAt: { type: Date },
  grantedScopes: [{ type: String }],
  declinedScopes: [{ type: String }],
  status: { type: String, enum: ['active', 'needs_reauth', 'revoked'], default: 'active' },
  lastError: {
    code: Number,
    message: String,
    at: Date
  }
}, { timestamps: true });

metaConnectionSchema.index({ tenantId: 1, fbUserId: 1 }, { unique: true });
metaConnectionSchema.index({ fbUserId: 1 }); // deauth / deletion lookups

module.exports = mongoose.model('MetaConnection', metaConnectionSchema);
