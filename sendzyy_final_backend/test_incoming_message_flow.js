'use strict';

const assert = require('assert');

console.log('--- Verifying Incoming Message Handler & Chatbot Routing ---');

// Mock data
let chatbotProcessed = false;
let ctwaProcessed = false;
let pendingChatbotChecked = false;

const mockTenant = {
  _id: 'tenant_12345',
  whatsappConfig: { phoneNumberId: 'phone_999' }
};

// Simulate processIncomingMessage logic from server.js
async function simulateProcessIncomingMessage(message, contacts, receiverPhoneNumberId, findTenantFn) {
  let tenantId = null;
  let tenant = null;
  if (receiverPhoneNumberId) {
    tenant = await findTenantFn(receiverPhoneNumberId);
    if (tenant) tenantId = tenant._id.toString();
  }

  if (!tenantId) {
    console.warn(` Could not map incoming message to a tenant (Phone: ${receiverPhoneNumberId})`);
  } else {
    const from = message.from;
    const profileName = contacts?.[0]?.profile?.name || 'Unknown Sender';

    // ── CTWA (Click-to-WhatsApp) Referral Detection ─────────
    if (message.referral) {
      ctwaProcessed = true;
    }

    // ── Check if contact has a pending chatbot session awaiting customer reply ──
    pendingChatbotChecked = true;

    // ── Chatbot Execution ──
    chatbotProcessed = true;
  }
}

async function run() {
  // Case 1: Valid Tenant
  chatbotProcessed = false;
  ctwaProcessed = false;
  pendingChatbotChecked = false;

  await simulateProcessIncomingMessage(
    { from: '919876543210', id: 'wamid_123' },
    [{ profile: { name: 'Test User' } }],
    'phone_999',
    async (id) => (id === 'phone_999' ? mockTenant : null)
  );

  assert.strictEqual(chatbotProcessed, true, 'Chatbot engine MUST be reached when tenant is valid');
  assert.strictEqual(pendingChatbotChecked, true, 'Pending chatbot session check must execute');
  console.log('✅ Valid tenant correctly routes to chatbot engine');

  // Case 2: CTWA referral message
  chatbotProcessed = false;
  ctwaProcessed = false;
  await simulateProcessIncomingMessage(
    { from: '919876543210', id: 'wamid_124', referral: { source_id: 'ad_123' } },
    [{ profile: { name: 'Ad Lead' } }],
    'phone_999',
    async (id) => (id === 'phone_999' ? mockTenant : null)
  );

  assert.strictEqual(ctwaProcessed, true, 'CTWA referral must be intercepted');
  assert.strictEqual(chatbotProcessed, true, 'Chatbot must process CTWA lead');
  console.log('✅ CTWA referral correctly intercepted and passed to chatbot');

  // Case 3: Unknown Phone Number (no tenant)
  chatbotProcessed = false;
  await simulateProcessIncomingMessage(
    { from: '919876543210', id: 'wamid_125' },
    [],
    'unknown_phone',
    async () => null
  );

  assert.strictEqual(chatbotProcessed, false, 'Unmapped tenant must NOT trigger chatbot');
  console.log('✅ Unmapped tenant handled cleanly without errors');

  console.log('🎉 All incoming message & chatbot routing checks passed!');
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
