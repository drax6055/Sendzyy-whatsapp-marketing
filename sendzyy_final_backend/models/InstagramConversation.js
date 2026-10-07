const mongoose = require('mongoose');

const instagramConversationSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    instagramAccountId: { type: String, required: true, index: true }, // The business account ID
    igsid: { type: String, required: true, index: true }, // The customer's Instagram-scoped ID
    name: { type: String, default: '' },
    username: { type: String, default: '' },
    profilePic: { type: String, default: '' },
    lastMessage: { type: String, default: '' },
    lastMessageAt: { type: Date, default: Date.now, index: true },
    lastCustomerMessageAt: { type: Date, default: Date.now },
    unreadCount: { type: Number, default: 0 },
    // Human-Agent Takeover: When true, automated DM bots/rules will not reply to this customer
    isHumanTakeover: { type: Boolean, default: false },
    humanTakeoverAt: { type: Date, default: null },
    status: { type: String, enum: ['active', 'closed', 'archived'], default: 'active' },
}, { timestamps: true });

// Compound index to guarantee unique conversation per tenant, business account, and customer IGSID
instagramConversationSchema.index({ tenantId: 1, instagramAccountId: 1, igsid: 1 }, { unique: true });
instagramConversationSchema.index({ tenantId: 1, lastMessageAt: -1 });

module.exports = mongoose.model('InstagramConversation', instagramConversationSchema);
