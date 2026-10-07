const mongoose = require('mongoose');

const instagramProcessedCommentSchema = new mongoose.Schema({
    tenantId:       { type: String, required: true },
    commentId:      { type: String, required: true, unique: true },
    mediaId:        { type: String },
    fromUsername:   { type: String },
    fromUserId:     { type: String },
    commentText:    { type: String },
    automationId:   { type: mongoose.Schema.Types.ObjectId, ref: 'InstagramCommentAutomation' },
    publicReplied:  { type: Boolean, default: false },
    privateDmSent:  { type: Boolean, default: false },
    error:          { type: String, default: null },
}, { timestamps: true });

// Auto-expire processed comment log after 30 days
instagramProcessedCommentSchema.index({ createdAt: 1 }, { expireAfterSeconds: 30 * 24 * 60 * 60 });

module.exports = mongoose.model('InstagramProcessedComment', instagramProcessedCommentSchema);
