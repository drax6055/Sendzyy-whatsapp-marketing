'use strict';

const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const axios = require('axios');
const jwt = require('jsonwebtoken');

const MetaConnection = require('../models/MetaConnection');
const MetaPageConnection = require('../models/MetaPageConnection');
const MetaLeadForm = require('../models/MetaLeadForm');
const { encryptToken, decryptToken } = require('../utils/cryptoUtils');
const { META_GRAPH_VERSION, GRAPH_BASE_URL, OAUTH_SCOPES } = require('../config/meta');
const { ingestInstantFormLead } = require('../services/metaLeadIngestion');

// Auth middleware
const authenticate = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = (authHeader && authHeader.split(' ')[1]) || req.query.token;
  if (!token) return res.sendStatus(401);
  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    if (!user.tenantId) return res.status(401).json({ error: 'Tenant ID missing' });
    req.user = user;
    next();
  });
};

function getStateSecret() {
  return process.env.META_STATE_SECRET || process.env.META_APP_SECRET || 'state_secret_fallback';
}

function getRedirectUri(req) {
  if (process.env.META_OAUTH_REDIRECT_URI) return process.env.META_OAUTH_REDIRECT_URI;
  const proto = req.headers['x-forwarded-proto'] || req.protocol;
  const host = req.headers['x-forwarded-host'] || req.get('host');
  return `${proto}://${host}/api/meta/callback`;
}

/**
 * 1. GET /api/meta/connect-url
 * Returns Facebook Login dialog URL with signed HMAC state
 */
router.get('/connect-url', authenticate, (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    const appId = process.env.META_APP_ID;
    if (!appId) {
      return res.status(500).json({ error: 'META_APP_ID not configured in backend .env' });
    }

    const statePayload = Buffer.from(JSON.stringify({
      tenantId,
      nonce: crypto.randomBytes(16).toString('hex'),
      exp: Date.now() + 10 * 60 * 1000 // 10 minutes
    })).toString('base64url');

    const signature = crypto
      .createHmac('sha256', getStateSecret())
      .update(statePayload)
      .digest('base64url');

    const state = `${statePayload}.${signature}`;
    const redirectUri = getRedirectUri(req);

    const dialogUrl =
      `https://www.facebook.com/${META_GRAPH_VERSION}/dialog/oauth` +
      `?client_id=${appId}` +
      `&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&state=${state}` +
      `&scope=${encodeURIComponent(OAUTH_SCOPES.join(','))}` +
      `&response_type=code`;

    res.json({ url: dialogUrl });
  } catch (err) {
    console.error('GET /api/meta/connect-url error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * 2. GET /api/meta/callback
 * Handles OAuth callback from Facebook
 */
router.get('/callback', async (req, res) => {
  const { code, state, error, error_description } = req.query;

  if (error) {
    console.error('[MetaOAuth] User cancelled or Facebook returned error:', error_description || error);
    return res.status(400).send(`<h3>Authorization Failed</h3><p>${error_description || error}</p>`);
  }

  if (!code || !state || !state.includes('.')) {
    return res.status(400).send('<h3>Invalid Request</h3><p>Missing code or invalid state</p>');
  }

  try {
    const [payloadB64, signature] = state.split('.');
    const expectedSig = crypto
      .createHmac('sha256', getStateSecret())
      .update(payloadB64)
      .digest('base64url');

    if (signature !== expectedSig) {
      return res.status(403).send('<h3>Forbidden</h3><p>State signature verification failed</p>');
    }

    const stateData = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
    if (Date.now() > stateData.exp) {
      return res.status(400).send('<h3>Session Expired</h3><p>Authorization request timed out. Please try again.</p>');
    }

    const tenantId = stateData.tenantId;
    const appId = process.env.META_APP_ID;
    const appSecret = process.env.META_APP_SECRET;
    const redirectUri = getRedirectUri(req);

    // Step 1: Exchange code for short-lived user token
    const tokenResp = await axios.get(`${GRAPH_BASE_URL}/oauth/access_token`, {
      params: {
        client_id: appId,
        client_secret: appSecret,
        redirect_uri: redirectUri,
        code
      }
    });
    const shortLivedToken = tokenResp.data.access_token;

    // Step 2: Exchange for long-lived user token (~60 days)
    const longLivedResp = await axios.get(`${GRAPH_BASE_URL}/oauth/access_token`, {
      params: {
        grant_type: 'fb_exchange_token',
        client_id: appId,
        client_secret: appSecret,
        fb_exchange_token: shortLivedToken
      }
    });
    const userToken = longLivedResp.data.access_token;
    const expiresIn = longLivedResp.data.expires_in || 5184000; // ~60 days default

    // Step 3: Fetch User ID & permissions
    const meResp = await axios.get(`${GRAPH_BASE_URL}/me`, {
      params: { fields: 'id,name', access_token: userToken }
    });
    const fbUserId = meResp.data.id;
    const fbUserName = meResp.data.name || '';

    let grantedScopes = [];
    let declinedScopes = [];
    try {
      const permResp = await axios.get(`${GRAPH_BASE_URL}/me/permissions`, {
        params: { access_token: userToken }
      });
      for (const p of permResp.data?.data || []) {
        if (p.status === 'granted') grantedScopes.push(p.permission);
        else declinedScopes.push(p.permission);
      }
    } catch (_) {}

    // Step 4: Upsert MetaConnection
    const metaConn = await MetaConnection.findOneAndUpdate(
      { tenantId, fbUserId },
      {
        tenantId,
        fbUserId,
        fbUserName,
        userAccessToken: encryptToken(userToken),
        tokenExpiresAt: new Date(Date.now() + expiresIn * 1000),
        grantedScopes,
        declinedScopes,
        status: 'active',
        lastError: null
      },
      { upsert: true, new: true }
    );

    // Step 5: Query /me/accounts for Page tokens (these tokens do NOT expire when derived from long-lived user token)
    const accountsResp = await axios.get(`${GRAPH_BASE_URL}/me/accounts`, {
      params: { fields: 'id,name,access_token,tasks', access_token: userToken }
    });

    const pages = accountsResp.data?.data || [];
    let connectedPagesCount = 0;

    for (const page of pages) {
      const pageId = String(page.id);
      const pageName = page.name || 'Facebook Page';
      const pageAccessToken = page.access_token;

      // Check if page is already connected to another tenant
      const existingConn = await MetaPageConnection.findOne({ pageId });
      if (existingConn && existingConn.tenantId !== tenantId) {
        console.warn(`[MetaOAuth] Page ${pageId} (${pageName}) already bound to another tenant: ${existingConn.tenantId}`);
        continue;
      }

      // Upsert MetaPageConnection
      const pageConn = await MetaPageConnection.findOneAndUpdate(
        { pageId },
        {
          tenantId,
          connectionId: metaConn._id,
          pageId,
          pageName,
          pageAccessToken: encryptToken(pageAccessToken),
          status: 'active',
          lastError: null
        },
        { upsert: true, new: true }
      );

      // Auto-subscribe page to leadgen webhooks
      try {
        await axios.post(`${GRAPH_BASE_URL}/${pageId}/subscribed_apps`, null, {
          params: {
            subscribed_fields: 'leadgen',
            access_token: pageAccessToken
          }
        });
        pageConn.isSubscribed = true;
        pageConn.subscribedAt = new Date();
        await pageConn.save();
      } catch (subErr) {
        console.warn(`[MetaOAuth] Could not auto-subscribe page ${pageId}:`, subErr.response?.data?.error?.message || subErr.message);
      }

      // Discover and record forms
      try {
        const formsResp = await axios.get(`${GRAPH_BASE_URL}/${pageId}/leadgen_forms`, {
          params: {
            fields: 'id,name,status,questions',
            access_token: pageAccessToken
          }
        });
        for (const form of (formsResp.data?.data || [])) {
          await MetaLeadForm.findOneAndUpdate(
            { tenantId, formId: String(form.id) },
            {
              tenantId,
              pageId,
              formId: String(form.id),
              name: form.name || 'Instant Form',
              status: form.status || 'ACTIVE',
              questions: form.questions || []
            },
            { upsert: true }
          );
        }
      } catch (formErr) {
        console.warn(`[MetaOAuth] Could not discover forms for page ${pageId}:`, formErr.message);
      }

      connectedPagesCount++;
    }

    // Success response to browser window
    res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Facebook Connected Successfully</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; text-align: center; padding: 40px; background: #0f172a; color: #f8fafc; }
            .card { max-width: 480px; margin: 0 auto; background: #1e293b; border-radius: 16px; padding: 32px; border: 1px solid #334155; }
            h2 { color: #38bdf8; margin-bottom: 12px; }
            p { color: #94a3b8; font-size: 15px; line-height: 1.5; }
            .badge { display: inline-block; padding: 6px 14px; background: #064e3b; color: #34d399; border-radius: 20px; font-weight: 600; margin-top: 16px; }
          </style>
        </head>
        <body>
          <div class="card">
            <h2>Facebook Connected!</h2>
            <p>Welcome, <strong>${fbUserName}</strong>. We connected <strong>${connectedPagesCount} Page(s)</strong> to your Sendzyy workspace.</p>
            <div class="badge">Leads Sync Active</div>
            <p style="margin-top:24px; font-size: 13px;">This window can now be closed.</p>
          </div>
          <script>
            if (window.opener) {
              window.opener.postMessage({ type: 'META_AUTH_SUCCESS', pagesCount: ${connectedPagesCount} }, '*');
              setTimeout(() => window.close(), 1800);
            }
          </script>
        </body>
      </html>
    `);
  } catch (err) {
    console.error('[MetaOAuth] Callback error:', err.response?.data || err.message);
    res.status(500).send(`<h3>Connection Failed</h3><p>${err.response?.data?.error?.message || err.message}</p>`);
  }
});

/**
 * 3. GET /api/meta/status
 * Returns overall connection status for tenant
 */
router.get('/status', authenticate, async (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    const connection = await MetaConnection.findOne({ tenantId, status: 'active' }).lean();
    const pages = await MetaPageConnection.find({ tenantId }).lean();
    const formsCount = await MetaLeadForm.countDocuments({ tenantId });

    res.json({
      isConnected: Boolean(connection && pages.length > 0),
      connection: connection ? {
        fbUserId: connection.fbUserId,
        fbUserName: connection.fbUserName,
        status: connection.status,
        tokenExpiresAt: connection.tokenExpiresAt,
        grantedScopes: connection.grantedScopes || []
      } : null,
      pagesCount: pages.length,
      pages: pages.map(p => ({
        pageId: p.pageId,
        pageName: p.pageName,
        status: p.status,
        isSubscribed: p.isSubscribed,
        subscribedAt: p.subscribedAt,
        lastError: p.lastError
      })),
      formsCount
    });
  } catch (err) {
    console.error('GET /api/meta/status error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * 4. GET /api/meta/pages
 * Lists all connected Facebook pages for tenant
 */
router.get('/pages', authenticate, async (req, res) => {
  try {
    const pages = await MetaPageConnection.find({ tenantId: req.user.tenantId }).sort({ createdAt: -1 }).lean();
    res.json({
      pages: pages.map(p => ({
        id: p._id,
        pageId: p.pageId,
        pageName: p.pageName,
        status: p.status,
        isSubscribed: p.isSubscribed,
        subscribedAt: p.subscribedAt,
        lastError: p.lastError
      }))
    });
  } catch (err) {
    console.error('GET /api/meta/pages error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * 5. POST /api/meta/pages/:id/subscribe
 * Subscribes a connected page to leadgen webhooks
 */
router.post('/pages/:id/subscribe', authenticate, async (req, res) => {
  try {
    const page = await MetaPageConnection.findOne({
      _id: req.params.id,
      tenantId: req.user.tenantId
    });
    if (!page) return res.status(404).json({ error: 'Page connection not found' });

    const pageToken = decryptToken(page.pageAccessToken);
    await axios.post(`${GRAPH_BASE_URL}/${page.pageId}/subscribed_apps`, null, {
      params: {
        subscribed_fields: 'leadgen',
        access_token: pageToken
      }
    });

    page.isSubscribed = true;
    page.subscribedAt = new Date();
    page.status = 'active';
    page.lastError = null;
    await page.save();

    res.json({ success: true, pageId: page.pageId, isSubscribed: true });
  } catch (err) {
    console.error('POST /api/meta/pages/:id/subscribe error:', err.response?.data || err.message);
    res.status(500).json({ error: err.response?.data?.error?.message || err.message });
  }
});

/**
 * 6. POST /api/meta/pages/:id/test-access
 * Diagnostic check verifying page token and Leads Access permissions
 */
router.post('/pages/:id/test-access', authenticate, async (req, res) => {
  try {
    const page = await MetaPageConnection.findOne({
      _id: req.params.id,
      tenantId: req.user.tenantId
    });
    if (!page) return res.status(404).json({ error: 'Page connection not found' });

    const pageToken = decryptToken(page.pageAccessToken);

    // Test 1: Page metadata query
    const pageInfoResp = await axios.get(`${GRAPH_BASE_URL}/${page.pageId}`, {
      params: { fields: 'id,name', access_token: pageToken }
    });

    // Test 2: Subscribed apps query
    const subResp = await axios.get(`${GRAPH_BASE_URL}/${page.pageId}/subscribed_apps`, {
      params: { access_token: pageToken }
    });
    const isAppSubscribed = (subResp.data?.data || []).some(app =>
      (app.subscribed_fields || []).includes('leadgen')
    );

    // Test 3: Leadgen forms read test
    const formsResp = await axios.get(`${GRAPH_BASE_URL}/${page.pageId}/leadgen_forms`, {
      params: { fields: 'id,name', limit: 3, access_token: pageToken }
    });

    page.status = 'active';
    page.isSubscribed = isAppSubscribed;
    page.lastError = null;
    await page.save();

    res.json({
      healthy: true,
      pageName: pageInfoResp.data.name,
      isSubscribed: isAppSubscribed,
      formsDiscovered: (formsResp.data?.data || []).length,
      message: 'Meta connection is healthy and authorized to retrieve leads.'
    });
  } catch (err) {
    const metaError = err.response?.data?.error || {};
    const code = metaError.code;
    let advice = 'Check your Facebook page roles and permissions.';

    if (code === 190) {
      advice = 'Page access token has expired or was revoked. Please reconnect your Facebook account.';
    } else if (code === 100 || code === 200) {
      advice = 'Missing Leads Access in Meta Business Suite. Ask your Business Manager Admin to grant Leads Access in Business Settings -> Integrations -> Leads Access.';
    }

    res.status(400).json({
      healthy: false,
      code,
      error: metaError.message || err.message,
      advice
    });
  }
});

/**
 * 7. DELETE /api/meta/pages/:id
 * Disconnects a page from tenant
 */
router.delete('/pages/:id', authenticate, async (req, res) => {
  try {
    const page = await MetaPageConnection.findOne({
      _id: req.params.id,
      tenantId: req.user.tenantId
    });
    if (!page) return res.status(404).json({ error: 'Page connection not found' });

    // Try unsubscribing webhook
    try {
      const pageToken = decryptToken(page.pageAccessToken);
      await axios.delete(`${GRAPH_BASE_URL}/${page.pageId}/subscribed_apps`, {
        params: { access_token: pageToken }
      });
    } catch (_) {}

    await MetaPageConnection.findByIdAndDelete(page._id);
    await MetaLeadForm.deleteMany({ tenantId: req.user.tenantId, pageId: page.pageId });

    res.json({ success: true, message: 'Page disconnected successfully' });
  } catch (err) {
    console.error('DELETE /api/meta/pages/:id error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * 8. GET /api/meta/forms
 * Lists all Instant Forms across connected pages
 */
router.get('/forms', authenticate, async (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    const { pageId, refresh } = req.query;

    const query = { tenantId };
    if (pageId) query.pageId = pageId;

    // Optional on-demand refresh from Graph API
    if (refresh === 'true') {
      const pages = await MetaPageConnection.find(pageId ? { tenantId, pageId } : { tenantId, status: 'active' });
      for (const page of pages) {
        try {
          const pageToken = decryptToken(page.pageAccessToken);
          const formsResp = await axios.get(`${GRAPH_BASE_URL}/${page.pageId}/leadgen_forms`, {
            params: {
              fields: 'id,name,status,questions',
              access_token: pageToken
            }
          });
          for (const form of (formsResp.data?.data || [])) {
            await MetaLeadForm.findOneAndUpdate(
              { tenantId, formId: String(form.id) },
              {
                tenantId,
                pageId: page.pageId,
                formId: String(form.id),
                name: form.name || 'Instant Form',
                status: form.status || 'ACTIVE',
                questions: form.questions || []
              },
              { upsert: true }
            );
          }
        } catch (e) {
          console.warn(`[MetaForms] Could not refresh forms for page ${page.pageId}:`, e.message);
        }
      }
    }

    const forms = await MetaLeadForm.find(query).sort({ createdAt: -1 }).lean();
    res.json({ forms });
  } catch (err) {
    console.error('GET /api/meta/forms error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * 9. POST /api/meta/forms/:id/toggle-sync
 * Toggles syncEnabled for a given form
 */
router.post('/forms/:id/toggle-sync', authenticate, async (req, res) => {
  try {
    const form = await MetaLeadForm.findOne({
      _id: req.params.id,
      tenantId: req.user.tenantId
    });
    if (!form) return res.status(404).json({ error: 'Form not found' });

    form.syncEnabled = req.body.syncEnabled !== undefined ? Boolean(req.body.syncEnabled) : !form.syncEnabled;
    await form.save();

    res.json({ success: true, formId: form.formId, syncEnabled: form.syncEnabled });
  } catch (err) {
    console.error('POST /api/meta/forms/:id/toggle-sync error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * 10. POST /api/meta/forms/:id/sync-now
 * Runs immediate manual backfill of recent leads for that form
 */
router.post('/forms/:id/sync-now', authenticate, async (req, res) => {
  try {
    const form = await MetaLeadForm.findOne({
      _id: req.params.id,
      tenantId: req.user.tenantId
    });
    if (!form) return res.status(404).json({ error: 'Form not found' });

    const page = await MetaPageConnection.findOne({
      pageId: form.pageId,
      tenantId: req.user.tenantId,
      status: 'active'
    });
    if (!page) return res.status(400).json({ error: 'Connected page is not active' });

    const pageToken = decryptToken(page.pageAccessToken);

    // Fetch up to 50 recent leads from Graph API
    const leadsResp = await axios.get(`${GRAPH_BASE_URL}/${form.formId}/leads`, {
      params: {
        fields: 'id,created_time,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,is_organic,platform,field_data',
        limit: 50,
        access_token: pageToken
      }
    });

    const items = leadsResp.data?.data || [];
    let syncedCount = 0;

    for (const leadItem of items) {
      try {
        const result = await ingestInstantFormLead({
          pageId: page.pageId,
          leadgenId: String(leadItem.id),
          formId: form.formId,
          prefetched: leadItem
        });
        if (result?.ok) syncedCount++;
      } catch (ingestErr) {
        console.warn(`[SyncNow] Error ingesting lead ${leadItem.id}:`, ingestErr.message);
      }
    }

    form.lastSyncedAt = new Date();
    await form.save();

    res.json({
      success: true,
      formId: form.formId,
      totalFetched: items.length,
      syncedCount,
      message: `Backfill completed. ${syncedCount} new leads ingested.`
    });
  } catch (err) {
    console.error('POST /api/meta/forms/:id/sync-now error:', err.response?.data || err.message);
    res.status(500).json({ error: err.response?.data?.error?.message || err.message });
  }
});

module.exports = router;
