const mongoose = require('mongoose');

const instagramMessageSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    conversationId: { type: mongoose.Schema.Types.ObjectId, ref: 'InstagramConversation', required: true, index: true },
    igsid: { type: String, required: true, index: true }, // Customer IGSID
    isMe: { type: Boolean, required: true }, // true if sent by Sendzyy/business, false if sent by customer
    senderType: {
        type: String,
        enum: ['customer', 'agent', 'automation'],
        default: 'customer'
    },
    text: { type: String, default: '' },
    messageType: {
        type: String,
        enum: ['text', 'image', 'video', 'audio', 'quick_reply', 'postback', 'story_share', 'media', 'unsupported'],
        default: 'text'
    },
    mediaUrl: { type: String, default: '' },
    quickReplies: [{
        title: { type: String },
        payload: { type: String }
    }],
    mid: { type: String, default: '', index: true }, // Meta Instagram Message ID
    status: {
        type: String,
        enum: ['sent', 'delivered', 'read', 'failed'],
        default: 'sent'
    },
    errorDetails: { type: String, default: '' },
    timestamp: { type: Date, default: Date.now, index: true }
}, { timestamps: true });

instagramMessageSchema.index({ conversationId: 1, timestamp: 1 });
instagramMessageSchema.index({ tenantId: 1, timestamp: -1 });

module.exports = mongoose.model('InstagramMessage', instagramMessageSchema);
