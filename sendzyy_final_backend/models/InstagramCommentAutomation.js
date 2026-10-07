const mongoose = require('mongoose');

const selectedMediaItemSchema = new mongoose.Schema({
    id:               { type: String, required: true },
    caption:          { type: String, default: '' },
    mediaType:        { type: String, default: '' }, // IMAGE, VIDEO, CAROUSEL_ALBUM, etc.
    mediaProductType: { type: String, default: '' }, // FEED, REELS
    mediaUrl:         { type: String, default: '' },
    thumbnailUrl:     { type: String, default: '' },
    permalink:        { type: String, default: '' },
    timestamp:        { type: String, default: '' }
}, { _id: false });

const instagramCommentAutomationSchema = new mongoose.Schema({
    tenantId:           { type: String, required: true },
    name:               { type: String, required: true }, // Internal label e.g. "Pricing Reel Automation"
    postSelectionType:  { type: String, enum: ['all', 'specific'], default: 'all' },
    selectedMedia:      { type: [selectedMediaItemSchema], default: [] },
    triggerType:        { type: String, enum: ['all', 'keyword'], default: 'keyword' },
    triggerKeywords:    { type: [String], default: [] }, // e.g. ["price", "link", "details"]
    sendPublicReply:    { type: Boolean, default: true },
    publicReplyMessage: { type: String, default: '' }, // e.g. "Thanks! Check your DM 📩"
    sendPrivateDm:      { type: Boolean, default: true },
    privateDmMessage:   { type: String, required: true }, // e.g. "Hi {{username}}! Thanks for commenting. Here is the link..."
    isActive:           { type: Boolean, default: true },
}, { timestamps: true });

instagramCommentAutomationSchema.index({ tenantId: 1, isActive: 1 });

module.exports = mongoose.model('InstagramCommentAutomation', instagramCommentAutomationSchema);
