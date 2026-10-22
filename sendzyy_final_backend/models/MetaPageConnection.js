'use strict';

const mongoose = require('mongoose');

const metaPageConnectionSchema = new mongoose.Schema({
  tenantId: { type: String, required: true, index: true },
  connectionId: { type: mongoose.Schema.Types.ObjectId, ref: 'MetaConnection', required: true },
  pageId: { type: String, required: true, unique: true }, // a Page belongs to one tenant at a time
  pageName: { type: String, default: '' },
  pageAccessToken: { type: String, required: true },     // AES-256-GCM encrypted
  status: { 
    type: String, 
    enum: ['active', 'needs_reauth', 'needs_attention', 'disconnected'], 
    default: 'active' 
  },
  isSubscribed: { type: Boolean, default: false },
  subscribedAt: { type: Date },
  lastError: { 
    code: Number, 
    message: String, 
    at: Date 
  }
}, { timestamps: true });

metaPageConnectionSchema.index({ tenantId: 1, status: 1 });

module.exports = mongoose.model('MetaPageConnection', metaPageConnectionSchema);
