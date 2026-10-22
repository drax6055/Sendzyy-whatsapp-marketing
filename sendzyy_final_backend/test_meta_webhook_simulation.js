'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { verifyMetaWebhookSignature } = require('./middleware/verifyMetaSignature');

console.log('--- Testing Meta Webhook Verification & Trigger Specificity ---');

// 1. Signature Verification Test
const testSecret = 'mock_meta_app_secret_abc123';
process.env.META_APP_SECRET = testSecret;

const mockPayload = JSON.stringify({
  object: 'page',
  entry: [{
    id: '100123456789',
    time: 1776745000,
    changes: [{
      field: 'leadgen',
      value: {
        leadgen_id: '45678912345',
        page_id: '100123456789',
        form_id: '789123456',
        created_time: 1776745000
      }
    }]
  }]
});

const validHmac = crypto.createHmac('sha256', testSecret).update(mockPayload).digest('hex');
const req = {
  headers: { 'x-hub-signature-256': `sha256=${validHmac}` },
  rawBody: Buffer.from(mockPayload),
  body: JSON.parse(mockPayload)
};

let nextCalled = false;
const res = {
  status: (code) => ({
    send: (msg) => { throw new Error(`HTTP ${code}: ${msg}`); }
  })
};

verifyMetaWebhookSignature(req, res, () => {
  nextCalled = true;
});
assert.strictEqual(nextCalled, true, 'Valid signature must allow webhook through');
console.log('✅ HMAC-SHA256 Webhook signature validation passed');

// Test Invalid Signature
let invalidBlocked = false;
const badReq = {
  headers: { 'x-hub-signature-256': 'sha256=invalidhash99999999999999999999999999999999999999999999999999999999' },
  rawBody: Buffer.from(mockPayload),
  body: JSON.parse(mockPayload)
};
const badRes = {
  status: (code) => ({
    send: (msg) => {
      if (code === 403) invalidBlocked = true;
    }
  })
};
verifyMetaWebhookSignature(badReq, badRes, () => {
  throw new Error('Should not have called next() for invalid signature');
});
assert.strictEqual(invalidBlocked, true, 'Tampered/invalid signature must return 403');
console.log('✅ Invalid signature correctly rejected with 403');

// 2. Specificity Calculation Test
const specificity = t =>
  (t.adId ? 4 : 0) +
  (t.campaignId ? 3 : 0) +
  (t.formId ? 3 : 0) +
  (t.adType && t.adType !== 'any' ? 1 : 0) +
  (t.source === 'meta_ads' ? 0.5 : 0);

const generalTrigger = { name: 'Catch-all', source: 'meta_ads', adType: 'any' };
const instantFormAnyTrigger = { name: 'Any Instant Form', source: 'meta_ads', adType: 'instant_form' };
const specificFormTrigger = { name: 'Diwali Promo Form', source: 'meta_ads', adType: 'instant_form', formId: '789123456' };
const specificAdTrigger = { name: 'Ad Variation A', source: 'meta_ads', adType: 'instant_form', formId: '789123456', adId: 'ad_999' };

const triggers = [generalTrigger, specificAdTrigger, instantFormAnyTrigger, specificFormTrigger];
triggers.sort((a, b) => specificity(b) - specificity(a));

assert.strictEqual(triggers[0].name, 'Ad Variation A', 'Most specific trigger (adId + formId) must win');
assert.strictEqual(triggers[1].name, 'Diwali Promo Form', 'Form-level trigger must be second');
assert.strictEqual(triggers[2].name, 'Any Instant Form', 'Type-level trigger must be third');
assert.strictEqual(triggers[3].name, 'Catch-all', 'Generic catch-all must be last');
console.log('✅ Trigger specificity ordering verified');

console.log('🎉 All webhook & trigger simulation tests passed successfully!');
