'use strict';

const mongoose = require('mongoose');

const metaDeletionRequestSchema = new mongoose.Schema({
  confirmationCode: { type: String, unique: true, required: true },
  fbUserId: { type: String, required: true },
  status: { type: String, enum: ['pending', 'completed'], default: 'pending' },
  completedAt: { type: Date }
}, { timestamps: true });

module.exports = mongoose.model('MetaDeletionRequest', metaDeletionRequestSchema);
