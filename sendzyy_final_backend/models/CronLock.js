'use strict';

const mongoose = require('mongoose');

const cronLockSchema = new mongoose.Schema({
  key: { type: String, unique: true, required: true },
  lockedUntil: { type: Date, required: true }
}, { timestamps: true });

module.exports = mongoose.model('CronLock', cronLockSchema);
