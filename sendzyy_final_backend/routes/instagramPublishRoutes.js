const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');

const InstagramPost = require('../models/InstagramPost');
const instagramPublishService = require('../services/instagramPublishService');

// Tenant accessor
const getTenantModel = (req) => req.app.get('TenantModel') || require('mongoose').model('Tenant');

// JWT Auth Middleware
const authenticate = (req, res, next) => {
    const token = req.headers['authorization']?.split(' ')[1] || req.query.token;
    if (!token) return res.sendStatus(401);
    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        if (!user.tenantId) return res.status(401).json({ error: 'Invalid session' });
        req.user = user;
        next();
    });
};

// Ensure uploads folder exists
const uploadDir = path.join(__dirname, '..', 'uploads', 'instagram_media');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Multer Storage Configuration
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
        const ext = path.extname(file.originalname) || '.jpg';
        const uniqueName = `ig_${Date.now()}_${uuidv4().slice(0, 8)}${ext.toLowerCase()}`;
        cb(null, uniqueName);
    }
});

const fileFilter = (req, file, cb) => {
    const allowedMimes = [
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp',
        'video/mp4',
        'video/quicktime'
    ];
    if (allowedMimes.includes(file.mimetype.toLowerCase())) {
        cb(null, true);
    } else {
        cb(new Error(`Unsupported file type: ${file.mimetype}. Instagram supports JPG, PNG, WEBP, MP4, and MOV.`));
    }
};

const upload = multer({
    storage,
    fileFilter,
    limits: {
        fileSize: 100 * 1024 * 1024 // 100MB limit
    }
});

/**
 * 1. Upload Media Endpoint (Protected)
 * Supports single or multi-file uploads (for Carousels)
 */
router.post('/upload', authenticate, upload.array('media', 10), async (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ error: 'No media files uploaded' });
        }

        // Determine base public URL
        // In local/dev or production: use PUBLIC_BACKEND_URL or BASE_URL or req host
        const baseHost = (
            process.env.PUBLIC_BACKEND_URL ||
            process.env.BACKEND_URL ||
            process.env.BASE_URL ||
            `${req.protocol}://${req.get('host')}`
        ).replace(/\/$/, '');

        const filesData = req.files.map(file => {
            const publicUrl = `${baseHost}/uploads/instagram_media/${file.filename}`;
            return {
                url: publicUrl,
                filename: file.filename,
                originalName: file.originalname,
                mimetype: file.mimetype,
                size: file.size,
                localPath: file.path
            };
        });

        return res.json({
            success: true,
            files: filesData
        });
    } catch (error) {
        console.error('[IG Publish Upload] ❌ Error uploading files:', error);
        return res.status(500).json({ error: error.message || 'File upload failed' });
    }
});

/**
 * 2. Create and Publish / Schedule Post (Protected)
 */
router.post('/', authenticate, async (req, res) => {
    try {
        const {
            mediaType,
            aspectRatio = '1:1',
            mediaUrls = [],
            mediaLocalPaths = [],
            caption = '',
            hashtags = [],
            userTags = [],
            location = '',
            locationId = '',
            isScheduled = false,
            scheduledAt = null
        } = req.body;

        // Validation
        if (!['IMAGE', 'CAROUSEL', 'REEL'].includes(mediaType)) {
            return res.status(400).json({ error: 'Invalid mediaType. Allowed: IMAGE, CAROUSEL, REEL' });
        }

        if (!Array.isArray(mediaUrls) || mediaUrls.length === 0) {
            return res.status(400).json({ error: 'At least one media file is required' });
        }

        if (mediaType === 'CAROUSEL' && (mediaUrls.length < 2 || mediaUrls.length > 10)) {
            return res.status(400).json({ error: 'Carousel requires between 2 and 10 media items' });
        }

        // Verify Instagram connection
        const Tenant = getTenantModel(req);
        const tenant = await Tenant.findById(req.user.tenantId);
        if (!tenant) return res.status(404).json({ error: 'Tenant not found' });

        const config = tenant.instagramConfig;
        if (!config?.connected || !config?.accessToken || !config?.instagramAccountId) {
            return res.status(400).json({
                error: 'Instagram account is not connected. Please connect your account first in Profile & Setup.'
            });
        }

        // Schedule validation: Prevent past dates/times
        let targetScheduleDate = null;
        if (isScheduled) {
            if (!scheduledAt) {
                return res.status(400).json({ error: 'scheduledAt is required when scheduling a post' });
            }
            targetScheduleDate = new Date(scheduledAt);
            if (isNaN(targetScheduleDate.getTime())) {
                return res.status(400).json({ error: 'Invalid scheduledAt datetime' });
            }

            const now = new Date();
            // Disallow past date/time (with 1 minute grace for network transmission)
            if (targetScheduleDate.getTime() < now.getTime() - 60000) {
                return res.status(400).json({ error: 'Cannot schedule content for past dates or times' });
            }
        }

        // Create post document
        const post = new InstagramPost({
            tenantId: req.user.tenantId,
            igUserId: config.instagramAccountId,
            mediaType,
            aspectRatio,
            mediaUrls,
            mediaLocalPaths,
            caption: caption.slice(0, 2200),
            hashtags: Array.isArray(hashtags) ? hashtags.slice(0, 30) : [],
            userTags: Array.isArray(userTags) ? userTags : [],
            location,
            locationId,
            status: isScheduled ? 'scheduled' : 'publishing',
            scheduledAt: isScheduled ? targetScheduleDate : null
        });

        await post.save();

        // If Publish Now: execute immediately
        if (!isScheduled) {
            try {
                await instagramPublishService.executePublishPost(post, tenant);
                return res.json({
                    success: true,
                    message: 'Content published successfully to Instagram',
                    post
                });
            } catch (publishErr) {
                return res.status(500).json({
                    error: publishErr.message || 'Failed to publish content to Instagram',
                    post
                });
            }
        }

        // Scheduled successfully
        return res.json({
            success: true,
            message: 'Content scheduled successfully',
            post
        });

    } catch (error) {
        console.error('[IG Publish Route] ❌ Error creating post:', error);
        return res.status(500).json({ error: error.message || 'Internal Server Error' });
    }
});

/**
 * 3. Fetch Posts by Month/Year (Protected)
 * Supports calendar view
 */
router.get('/posts', authenticate, async (req, res) => {
    try {
        const { year, month } = req.query;
        const tenantId = req.user.tenantId;

        const query = { tenantId };

        if (year && month) {
            const yr = parseInt(year, 10);
            const m = parseInt(month, 10); // 1 to 12

            const startOfMonth = new Date(yr, m - 1, 1, 0, 0, 0, 0);
            const endOfMonth = new Date(yr, m, 0, 23, 59, 59, 999);

            query.$or = [
                { scheduledAt: { $gte: startOfMonth, $lte: endOfMonth } },
                { publishedAt: { $gte: startOfMonth, $lte: endOfMonth } },
                {
                    status: 'scheduled',
                    createdAt: { $gte: startOfMonth, $lte: endOfMonth }
                }
            ];
        }

        const posts = await InstagramPost.find(query).sort({ scheduledAt: 1, publishedAt: 1, createdAt: -1 });

        return res.json({
            success: true,
            posts
        });
    } catch (error) {
        console.error('[IG Publish Posts API] ❌ Error:', error);
        return res.status(500).json({ error: error.message || 'Failed to fetch Instagram posts' });
    }
});

/**
 * 4. Get Single Post Details (Protected)
 */
router.get('/posts/:id', authenticate, async (req, res) => {
    try {
        const post = await InstagramPost.findOne({
            _id: req.params.id,
            tenantId: req.user.tenantId
        });
        if (!post) return res.status(404).json({ error: 'Post not found' });
        return res.json({ success: true, post });
    } catch (error) {
        return res.status(500).json({ error: error.message || 'Error fetching post' });
    }
});

/**
 * 5. Delete / Cancel Scheduled Post (Protected)
 */
router.delete('/posts/:id', authenticate, async (req, res) => {
    try {
        const post = await InstagramPost.findOne({
            _id: req.params.id,
            tenantId: req.user.tenantId
        });
        if (!post) return res.status(404).json({ error: 'Post not found' });

        if (post.status === 'published') {
            return res.status(400).json({ error: 'Cannot cancel a post that has already been published' });
        }

        // Clean up local media files if any
        if (Array.isArray(post.mediaLocalPaths)) {
            for (const p of post.mediaLocalPaths) {
                try {
                    if (fs.existsSync(p)) fs.unlinkSync(p);
                } catch (_) {}
            }
        }

        await InstagramPost.deleteOne({ _id: post._id });
        return res.json({ success: true, message: 'Scheduled post cancelled successfully' });
    } catch (error) {
        return res.status(500).json({ error: error.message || 'Error deleting post' });
    }
});

/**
 * 6. Retry Failed Post (Protected)
 */
router.post('/posts/:id/retry', authenticate, async (req, res) => {
    try {
        const post = await InstagramPost.findOne({
            _id: req.params.id,
            tenantId: req.user.tenantId
        });
        if (!post) return res.status(404).json({ error: 'Post not found' });

        if (post.status === 'published') {
            return res.status(400).json({ error: 'Post is already published' });
        }

        const Tenant = getTenantModel(req);
        const tenant = await Tenant.findById(req.user.tenantId);
        if (!tenant) return res.status(404).json({ error: 'Tenant not found' });

        await instagramPublishService.executePublishPost(post, tenant);
        return res.json({ success: true, message: 'Post published successfully on retry', post });
    } catch (error) {
        return res.status(500).json({ error: error.message || 'Retry failed' });
    }
});

module.exports = router;

