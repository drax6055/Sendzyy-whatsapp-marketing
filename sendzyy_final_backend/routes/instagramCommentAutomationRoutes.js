const express = require('express');
const router = express.Router();
const axios = require('axios');
const jwt = require('jsonwebtoken');

const InstagramCommentAutomation = require('../models/InstagramCommentAutomation');

// Helper to access Tenant model
const getTenantModel = (req) => req.app.get('TenantModel') || require('mongoose').model('Tenant');

// Auth Middleware for protected endpoints
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

// ── 1. Fetch User Posts & Reels for Automation Selection (Protected) ──────────
router.get('/media', authenticate, async (req, res) => {
    try {
        const Tenant = getTenantModel(req);
        const tenant = await Tenant.findById(req.user.tenantId);
        if (!tenant || !tenant.instagramConfig?.connected) {
            return res.status(400).json({ error: 'Instagram account not connected' });
        }
        const { accessToken, instagramAccountId } = tenant.instagramConfig;
        if (!accessToken) return res.status(400).json({ error: 'Access token missing' });

        const apiVer = (process.env.INSTA_META_API_VERSION || process.env.META_API_VERSION || 'v26.0').toLowerCase();
        let mediaData = null;

        try {
            const resMedia = await axios.get(`https://graph.instagram.com/${apiVer}/me/media`, {
                params: {
                    fields: 'id,caption,media_type,media_product_type,media_url,thumbnail_url,permalink,timestamp',
                    access_token: accessToken,
                    limit: 50
                }
            });
            mediaData = resMedia.data;
        } catch (meErr) {
            console.warn('[IG COMMENT MEDIA] /me/media failed, trying /{instagramAccountId}/media:', meErr.response?.data || meErr.message);
            const resMediaAccount = await axios.get(`https://graph.instagram.com/${apiVer}/${instagramAccountId}/media`, {
                params: {
                    fields: 'id,caption,media_type,media_product_type,media_url,thumbnail_url,permalink,timestamp',
                    access_token: accessToken,
                    limit: 50
                }
            });
            mediaData = resMediaAccount.data;
        }

        return res.json(mediaData);
    } catch (error) {
        console.error('[IG COMMENT MEDIA] ❌ Error fetching Instagram media:', error.response?.data || error.message);
        const errMsg = error.response?.data?.error?.message || error.message || 'Failed to fetch Instagram posts';
        return res.status(500).json({ error: errMsg });
    }
});

// ── 2. Create Comment Automation (Protected) ───────────────────────────────────
router.post('/', authenticate, async (req, res) => {
    try {
        const {
            name,
            postSelectionType,
            selectedMedia,
            triggerType,
            triggerKeywords,
            sendPublicReply,
            publicReplyMessage,
            sendPrivateDm,
            privateDmMessage
        } = req.body;

        if (!name || !name.trim()) {
            return res.status(400).json({ error: 'Automation name is required' });
        }

        if (!privateDmMessage || !privateDmMessage.trim()) {
            return res.status(400).json({ error: 'Private DM message is required' });
        }

        if (postSelectionType === 'specific' && (!selectedMedia || selectedMedia.length === 0)) {
            return res.status(400).json({ error: 'Please select at least one Post or Reel' });
        }

        if (triggerType === 'keyword' && (!triggerKeywords || triggerKeywords.length === 0)) {
            return res.status(400).json({ error: 'Please enter at least one trigger keyword' });
        }

        const automation = await InstagramCommentAutomation.create({
            tenantId: req.user.tenantId,
            name: name.trim(),
            postSelectionType: postSelectionType || 'all',
            selectedMedia: selectedMedia || [],
            triggerType: triggerType || 'keyword',
            triggerKeywords: (triggerKeywords || []).map(k => k.trim().toLowerCase()).filter(k => k.length > 0),
            sendPublicReply: sendPublicReply !== false,
            publicReplyMessage: (publicReplyMessage || '').trim(),
            sendPrivateDm: sendPrivateDm !== false,
            privateDmMessage: privateDmMessage.trim(),
            isActive: true,
        });

        return res.status(201).json(automation);
    } catch (error) {
        console.error('[IG COMMENT AUTOMATION] Create error:', error.message);
        return res.status(500).json({ error: 'Failed to create comment automation' });
    }
});

// ── 3. List All Comment Automations (Protected) ───────────────────────────────
router.get('/', authenticate, async (req, res) => {
    try {
        const automations = await InstagramCommentAutomation.find({
            tenantId: req.user.tenantId
        }).sort({ createdAt: -1 });

        return res.json(automations);
    } catch (error) {
        console.error('[IG COMMENT AUTOMATION] List error:', error.message);
        return res.status(500).json({ error: 'Failed to fetch comment automations' });
    }
});

// ── 4. Get Single Comment Automation (Protected) ──────────────────────────────
router.get('/:id', authenticate, async (req, res) => {
    try {
        const automation = await InstagramCommentAutomation.findOne({
            _id: req.params.id,
            tenantId: req.user.tenantId
        });
        if (!automation) return res.status(404).json({ error: 'Comment automation not found' });
        return res.json(automation);
    } catch (error) {
        console.error('[IG COMMENT AUTOMATION] Get error:', error.message);
        return res.status(500).json({ error: 'Failed to fetch comment automation' });
    }
});

// ── 5. Update Comment Automation (Protected) ───────────────────────────────────
router.put('/:id', authenticate, async (req, res) => {
    try {
        const {
            name,
            postSelectionType,
            selectedMedia,
            triggerType,
            triggerKeywords,
            sendPublicReply,
            publicReplyMessage,
            sendPrivateDm,
            privateDmMessage,
            isActive
        } = req.body;

        if (name && !name.trim()) {
            return res.status(400).json({ error: 'Automation name cannot be empty' });
        }

        const updateData = {};
        if (name !== undefined) updateData.name = name.trim();
        if (postSelectionType !== undefined) updateData.postSelectionType = postSelectionType;
        if (selectedMedia !== undefined) updateData.selectedMedia = selectedMedia;
        if (triggerType !== undefined) updateData.triggerType = triggerType;
        if (triggerKeywords !== undefined) {
            updateData.triggerKeywords = triggerKeywords.map(k => k.trim().toLowerCase()).filter(k => k.length > 0);
        }
        if (sendPublicReply !== undefined) updateData.sendPublicReply = sendPublicReply;
        if (publicReplyMessage !== undefined) updateData.publicReplyMessage = publicReplyMessage.trim();
        if (sendPrivateDm !== undefined) updateData.sendPrivateDm = sendPrivateDm;
        if (privateDmMessage !== undefined) updateData.privateDmMessage = privateDmMessage.trim();
        if (isActive !== undefined) updateData.isActive = isActive;

        const automation = await InstagramCommentAutomation.findOneAndUpdate(
            { _id: req.params.id, tenantId: req.user.tenantId },
            updateData,
            { new: true, runValidators: true }
        );

        if (!automation) return res.status(404).json({ error: 'Comment automation not found' });
        return res.json(automation);
    } catch (error) {
        console.error('[IG COMMENT AUTOMATION] Update error:', error.message);
        return res.status(500).json({ error: 'Failed to update comment automation' });
    }
});

// ── 6. Toggle Active Status (Protected) ────────────────────────────────────────
router.patch('/:id/toggle', authenticate, async (req, res) => {
    try {
        const automation = await InstagramCommentAutomation.findOne({
            _id: req.params.id,
            tenantId: req.user.tenantId
        });
        if (!automation) return res.status(404).json({ error: 'Comment automation not found' });

        automation.isActive = !automation.isActive;
        await automation.save();
        return res.json({ id: automation._id, isActive: automation.isActive });
    } catch (error) {
        console.error('[IG COMMENT AUTOMATION] Toggle error:', error.message);
        return res.status(500).json({ error: 'Failed to toggle comment automation status' });
    }
});

// ── 7. Delete Comment Automation (Protected) ───────────────────────────────────
router.delete('/:id', authenticate, async (req, res) => {
    try {
        const result = await InstagramCommentAutomation.findOneAndDelete({
            _id: req.params.id,
            tenantId: req.user.tenantId
        });
        if (!result) return res.status(404).json({ error: 'Comment automation not found' });
        return res.json({ success: true });
    } catch (error) {
        console.error('[IG COMMENT AUTOMATION] Delete error:', error.message);
        return res.status(500).json({ error: 'Failed to delete comment automation' });
    }
});

module.exports = router;
