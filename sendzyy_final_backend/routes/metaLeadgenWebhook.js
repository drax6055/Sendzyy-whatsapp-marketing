'use strict';

const express = require('express');
const router = express.Router();
const { verifyMetaWebhookSignature } = require('../middleware/verifyMetaSignature');
const { ingestInstantFormLead } = require('../services/metaLeadIngestion');

/**
 * 1. Webhook Handshake Verification
 */
router.get('/api/webhooks/meta-leadgen', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  const expectedToken = process.env.META_LEADGEN_VERIFY_TOKEN || process.env.WEBHOOK_VERIFY_TOKEN;

  if (mode === 'subscribe' && token && token === expectedToken) {
    console.log('[MetaLeadgen] Verification handshake successful');
    return res.status(200).send(challenge);
  }

  console.warn('[MetaLeadgen] Webhook verification handshake failed (token mismatch or missing mode)');
  return res.sendStatus(403);
});

/**
 * 2. Inbound Leadgen Events
 */
router.post('/api/webhooks/meta-leadgen', verifyMetaWebhookSignature, async (req, res) => {
  // Acknowledge immediately to prevent Meta timeout and retry bursts
  res.status(200).send('EVENT_RECEIVED');

  try {
    const body = req.body;
    if (body?.object !== 'page') return;

    for (const entry of body.entry || []) {
      const pageId = String(entry.id);
      for (const change of entry.changes || []) {
        if (change.field !== 'leadgen') continue;
        const val = change.value || {};
        const leadgenId = String(val.leadgen_id || '');
        const formId = String(val.form_id || '');

        if (!leadgenId) continue;

        // Process asynchronously
        setImmediate(async () => {
          try {
            await ingestInstantFormLead({ pageId, leadgenId, formId });
          } catch (err) {
            console.error(`[MetaLeadgen] Failed to process leadgen event ${leadgenId}:`, err.message);
          }
        });
      }
    }
  } catch (err) {
    console.error('[MetaLeadgen] Error processing webhook payload:', err.message);
  }
});

module.exports = router;
