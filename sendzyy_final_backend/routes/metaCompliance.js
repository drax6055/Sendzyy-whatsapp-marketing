'use strict';

const express = require('express');
const router = express.Router();
const crypto = require('crypto');

const MetaConnection = require('../models/MetaConnection');
const MetaPageConnection = require('../models/MetaPageConnection');
const MetaDeletionRequest = require('../models/MetaDeletionRequest');
const MetaCache = require('../models/MetaCache');

router.use(express.urlencoded({ extended: false }));

const b64url = s => Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');

function parseSignedRequest(signedRequest, secret) {
  const [sigPart, payloadPart] = String(signedRequest || '').split('.');
  if (!sigPart || !payloadPart) throw new Error('Malformed signed_request');
  const data = JSON.parse(b64url(payloadPart).toString('utf8'));
  if (data.algorithm && String(data.algorithm).toUpperCase() !== 'HMAC-SHA256') {
    throw new Error('Unsupported signature algorithm');
  }
  const expected = crypto.createHmac('sha256', secret).update(payloadPart).digest();
  const got = b64url(sigPart);
  if (got.length !== expected.length || !crypto.timingSafeEqual(got, expected)) {
    throw new Error('Invalid signature');
  }
  return data;
}

/**
 * 1. POST /api/meta/compliance/deauth
 * Meta Deauthorization Callback: Revokes only this Facebook user's connections
 */
router.post('/api/meta/compliance/deauth', async (req, res) => {
  try {
    const secret = process.env.META_APP_SECRET;
    const { user_id } = parseSignedRequest(req.body.signed_request, secret);

    console.log(`[MetaCompliance] Deauth request received for FB user: ${user_id}`);
    const conns = await MetaConnection.find({ fbUserId: user_id });
    for (const c of conns) {
      await MetaPageConnection.updateMany(
        { connectionId: c._id },
        { status: 'disconnected', pageAccessToken: 'revoked', isSubscribed: false }
      );
      await MetaConnection.updateOne(
        { _id: c._id },
        { status: 'revoked', userAccessToken: 'revoked' }
      );
    }
    res.json({ status: 'success' });
  } catch (err) {
    console.error('[MetaCompliance] Deauth error:', err.message);
    res.sendStatus(400);
  }
});

/**
 * 2. POST /api/meta/compliance/data-deletion
 * Meta Data Deletion Request Callback: Records request, wipes tokens/credentials, and returns confirmation tracking URL
 */
router.post('/api/meta/compliance/data-deletion', async (req, res) => {
  try {
    const secret = process.env.META_APP_SECRET;
    const { user_id } = parseSignedRequest(req.body.signed_request, secret);
    const confirmationCode = crypto.randomBytes(12).toString('hex');

    await MetaDeletionRequest.create({ confirmationCode, fbUserId: user_id });

    // Asynchronous purge
    setImmediate(async () => {
      try {
        const conns = await MetaConnection.find({ fbUserId: user_id });
        for (const c of conns) {
          await MetaPageConnection.deleteMany({ connectionId: c._id });
          await MetaConnection.deleteOne({ _id: c._id });
        }
        await MetaCache.deleteMany({ key: { $regex: user_id } });
        await MetaDeletionRequest.updateOne(
          { confirmationCode },
          { status: 'completed', completedAt: new Date() }
        );
        console.log(`[MetaCompliance] Data deletion completed for FB user: ${user_id}`);
      } catch (purgeErr) {
        console.error(`[MetaCompliance] Purge error for ${user_id}:`, purgeErr.message);
      }
    });

    const baseUrl = process.env.APP_BASE_URL || 'https://appapi.sendzyy.com';
    res.json({
      url: `${baseUrl}/compliance/deletion-status?code=${confirmationCode}`,
      confirmation_code: confirmationCode
    });
  } catch (err) {
    console.error('[MetaCompliance] Data deletion error:', err.message);
    res.sendStatus(400);
  }
});

/**
 * 3. GET /compliance/deletion-status
 * Public status verification page for Meta App Review compliance
 */
router.get('/compliance/deletion-status', async (req, res) => {
  try {
    const code = String(req.query.code || '');
    const r = await MetaDeletionRequest.findOne({ confirmationCode: code });
    if (!r) {
      return res.status(404).send('<h3>Invalid Request</h3><p>Confirmation code not found.</p>');
    }
    res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Data Deletion Status - Sendzyy</title>
          <style>
            body { font-family: -apple-system, sans-serif; background: #0f172a; color: #f8fafc; padding: 40px; text-align: center; }
            .card { max-width: 500px; margin: 0 auto; background: #1e293b; border-radius: 12px; padding: 24px; border: 1px solid #334155; }
            h2 { color: #38bdf8; }
            .status { font-weight: bold; color: ${r.status === 'completed' ? '#34d399' : '#f59e0b'}; }
          </style>
        </head>
        <body>
          <div class="card">
            <h2>Data Deletion Request</h2>
            <p>Confirmation Code: <code>${r.confirmationCode}</code></p>
            <p>Status: <span class="status">${r.status.toUpperCase()}</span></p>
            <p style="font-size: 13px; color: #94a3b8;">User credentials and authentication tokens associated with Facebook ID have been purged.</p>
          </div>
        </body>
      </html>
    `);
  } catch (err) {
    res.status(500).send('Internal Server Error');
  }
});

module.exports = router;
