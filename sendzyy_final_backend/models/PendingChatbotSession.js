'use strict';

const mongoose = require('mongoose');

// PendingChatbotSession: Instant Form lead received a template message, chatbot initiates when lead replies
const pendingChatbotSchema = new mongoose.Schema({
  tenantId: { type: String, required: true },
  mobileNumber: { type: String, required: true },
  chatbotId: { type: String, required: true },
  leadId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lead' },
  expiresAt: { type: Date, required: true },
  consumedAt: { type: Date }
}, { timestamps: true });

pendingChatbotSchema.index({ tenantId: 1, mobileNumber: 1 });
pendingChatbotSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 }); // MongoDB TTL index

module.exports = mongoose.model('PendingChatbotSession', pendingChatbotSchema);
