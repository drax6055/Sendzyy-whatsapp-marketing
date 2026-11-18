const mongoose = require('mongoose');

const userTagSchema = new mongoose.Schema({
    username: { type: String, required: true },
    x: { type: Number, default: 0.5 }, // 0.0 to 1.0 coordinate
    y: { type: Number, default: 0.5 }, // 0.0 to 1.0 coordinate
}, { _id: false });

const instagramPostSchema = new mongoose.Schema({
    tenantId: {
        type: String,
        required: true,
        index: true
    },
    igUserId: {
        type: String,
        required: true
    },
    mediaType: {
        type: String,
        enum: ['IMAGE', 'CAROUSEL', 'REEL'],
        required: true
    },
    aspectRatio: {
        type: String,
        enum: ['4:5', '1:1', '1.91:1', '9:16'],
        default: '1:1'
    },
    mediaUrls: {
        type: [String],
        required: true
    },
    mediaLocalPaths: {
        type: [String],
        default: []
    },
    caption: {
        type: String,
        default: '',
        maxlength: 2200
    },
    hashtags: {
        type: [String],
        default: []
    },
    userTags: {
        type: [userTagSchema],
        default: []
    },
    location: {
        type: String,
        default: ''
    },
    locationId: {
        type: String,
        default: ''
    },
    status: {
        type: String,
        enum: ['scheduled', 'publishing', 'published', 'failed'],
        default: 'scheduled',
        index: true
    },
    scheduledAt: {
        type: Date,
        default: null,
        index: true
    },
    publishedAt: {
        type: Date,
        default: null
    },
    creationId: {
        type: String,
        default: ''
    },
    igMediaId: {
        type: String,
        default: ''
    },
    errorMessage: {
        type: String,
        default: ''
    },
    retryCount: {
        type: Number,
        default: 0
    }
}, {
    timestamps: true
});

// Composite indexes for fast tenant calendar querying and scheduler polling
instagramPostSchema.index({ tenantId: 1, scheduledAt: 1 });
instagramPostSchema.index({ tenantId: 1, publishedAt: 1 });
instagramPostSchema.index({ status: 1, scheduledAt: 1 });

module.exports = mongoose.model('InstagramPost', instagramPostSchema);

