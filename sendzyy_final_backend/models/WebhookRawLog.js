const mongoose = require('mongoose');

/**
 * WebhookRawLog Schema
 * Provides write-ahead persistence for incoming raw webhook payloads before acknowledging Meta with 200 OK.
 * 3-Day TTL (259,200s) for storage optimization; processed entries are additionally purged after 24h.
 */
const webhookRawLogSchema = new mongoose.Schema({
    payload: { type: mongoose.Schema.Types.Mixed, required: true },
    status: {
        type: String,
        enum: ['pending', 'processing', 'processed', 'failed'],
        default: 'pending',
        index: true
    },
    attempts: { type: Number, default: 0 },
    error: { type: String, default: null },
    receivedAt: {
        type: Date,
        default: Date.now,
        expires: 259200 // 3 days TTL in seconds (reduced from 30 days)
    }
}, { timestamps: true });

webhookRawLogSchema.index({ status: 1, createdAt: 1 });

module.exports = mongoose.model('WebhookRawLog', webhookRawLogSchema);
