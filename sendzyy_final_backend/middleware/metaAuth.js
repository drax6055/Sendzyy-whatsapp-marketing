'use strict';

const MetaAdToken = require('../models/MetaAdToken');
const { decryptSecret } = require('../cryptoUtils');

/**
 * Middleware to ensure the tenant has an active Meta Ads account connected
 * and attaches decrypted tokens to req.meta.
 */
async function requireMetaAuth(req, res, next) {
    try {
        const tenantId = req.user?.tenantId || req.user?.id || req.headers['x-tenant-id'];
        if (!tenantId) {
            return res.status(401).json({
                success: false,
                error: 'Unauthorized: missing tenantId in session'
            });
        }

        const tokenDoc = await MetaAdToken.findOne({ tenantId, status: 'connected' });
        if (!tokenDoc) {
            return res.status(400).json({
                success: false,
                code: 'META_NOT_CONNECTED',
                error: 'Meta Ad Account is not connected. Please connect your Facebook Business account first.'
            });
        }

        // Check token expiration
        if (tokenDoc.expiresAt && new Date() > tokenDoc.expiresAt) {
            tokenDoc.status = 'expired';
            await tokenDoc.save();
            return res.status(400).json({
                success: false,
                code: 'META_TOKEN_EXPIRED',
                error: 'Meta access token has expired. Please reconnect your Facebook account.'
            });
        }

        const accessToken = decryptSecret(tokenDoc.accessToken);
        const pageAccessToken = tokenDoc.pageAccessToken 
            ? decryptSecret(tokenDoc.pageAccessToken) 
            : accessToken;

        req.meta = {
            tokenDoc,
            accessToken,
            pageAccessToken,
            adAccountId: tokenDoc.adAccountId,
            pageId: tokenDoc.pageId,
            businessId: tokenDoc.businessId,
            instagramActorId: tokenDoc.instagramActorId
        };

        next();
    } catch (err) {
        console.error('[requireMetaAuth] Middleware error:', err);
        return res.status(500).json({
            success: false,
            error: 'Failed to verify Meta authentication: ' + err.message
        });
    }
}

module.exports = { requireMetaAuth };
