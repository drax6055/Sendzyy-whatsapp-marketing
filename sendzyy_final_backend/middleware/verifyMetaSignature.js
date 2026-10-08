const crypto = require('crypto');

/**
 * Middleware: Verify Meta Webhook Signature (X-Hub-Signature-256)
 * Uses HMAC-SHA256 with timingSafeEqual to protect against replay and spoofing attacks.
 */
function verifyMetaWebhookSignature(req, res, next) {
    const signature = req.headers['x-hub-signature-256'] || req.headers['x-hub-signature'];
    const candidateSecrets = [
        process.env.META_APP_SECRET,
        process.env.INSTAGRAM_CLIENT_SECRET,
        process.env.INSTA_APP_SECRET,
        process.env.META_CLIENT_SECRET
    ].filter(Boolean);

    if (candidateSecrets.length === 0) {
        if (process.env.NODE_ENV === 'production') {
            console.error('[Security] ❌ Neither META_APP_SECRET nor INSTAGRAM_CLIENT_SECRET is defined in production!');
            return res.status(403).send('Webhook secret misconfigured');
        }
        // In development/test mode, allow requests with a warning
        return next();
    }

    if (!signature) {
        console.warn('[Security] ⚠️ Missing X-Hub-Signature header on webhook request. Headers:', JSON.stringify(req.headers));
        if (process.env.NODE_ENV === 'production') {
            return res.status(401).send('Missing signature');
        }
        return next();
    }

    const elements = signature.split('=');
    const hashAlgo = elements[0] === 'sha1' ? 'sha1' : 'sha256';
    const signatureHash = elements[1] || '';
    const rawContent = req.rawBuffer || req.rawBody || (typeof req.body === 'string' ? req.body : JSON.stringify(req.body));

    let isValid = false;
    for (const secret of candidateSecrets) {
        try {
            const expectedHash = crypto
                .createHmac(hashAlgo, secret)
                .update(rawContent)
                .digest('hex');

            const sigBuf = Buffer.from(signatureHash, 'utf8');
            const expBuf = Buffer.from(expectedHash, 'utf8');
            if (sigBuf.length === expBuf.length && crypto.timingSafeEqual(sigBuf, expBuf)) {
                isValid = true;
                break;
            }
        } catch (hmacErr) {
            console.error('[Security] Error computing HMAC:', hmacErr.message);
        }
    }

    if (!isValid) {
        console.error(`[Security] ❌ Invalid ${hashAlgo.toUpperCase()} signature received for webhook. Candidate secrets count: ${candidateSecrets.length}`);
        return res.status(403).send('Invalid signature');
    }

    next();
}

module.exports = { verifyMetaWebhookSignature };
