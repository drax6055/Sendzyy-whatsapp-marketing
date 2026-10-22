'use strict';

const mongoose = require('mongoose');

const metaCacheSchema = new mongoose.Schema({
  key: { type: String, unique: true, required: true },
  value: { type: mongoose.Schema.Types.Mixed, default: {} },
  expiresAt: { type: Date, required: true }
}, { timestamps: true });

metaCacheSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 }); // MongoDB TTL auto-cleanup

module.exports = mongoose.model('MetaCache', metaCacheSchema);
