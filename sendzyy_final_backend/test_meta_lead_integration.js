'use strict';

const assert = require('assert');
const { encryptToken, decryptToken } = require('./cryptoUtils');
const { normalizePhone, normalizePhoneNumber } = require('./utils/phoneNormalizer');
const { parseLeadFields } = require('./services/parseLeadFields');

console.log('--- Testing Meta Ads Lead Integration Backend Utilities ---');

// 1. Crypto Test
const sampleToken = 'EAAXsampleMetaUserToken1234567890abcdefghijklmnopqrstuvwxyz';
const encrypted = encryptToken(sampleToken);
assert.notStrictEqual(encrypted, sampleToken, 'Encrypted token should not equal plaintext');
assert(encrypted.includes('.'), 'Encrypted token should be separated by dots (iv.tag.enc)');
const decrypted = decryptToken(encrypted);
assert.strictEqual(decrypted, sampleToken, 'Decrypted token must match original');
console.log('✅ Crypto encryptToken & decryptToken passed');

// 2. Phone Normalizer Test
const indianMobile = normalizePhone('9876543210', 'IN');
assert.strictEqual(indianMobile.valid, true);
assert.strictEqual(indianMobile.digits, '919876543210', 'Should prepend 91 for standard Indian mobile');

const leadingZero = normalizePhone('09876543210', 'IN');
assert.strictEqual(leadingZero.valid, true);
assert.strictEqual(leadingZero.digits, '919876543210', 'Should strip leading zero');

const withPlus = normalizePhone('+91 98765 43210', 'IN');
assert.strictEqual(withPlus.valid, true);
assert.strictEqual(withPlus.digits, '919876543210', 'Should normalize formatted +91 number');

const invalidDummy = normalizePhone('dummy_text', 'IN');
assert.strictEqual(invalidDummy.valid, false, 'Invalid dummy string should not throw and should flag valid: false');
console.log('✅ Phone Normalizer libphonenumber-js tests passed');

// 3. Field Parser Test
const mockFieldData = [
  { name: 'full_name', values: ['Priya Sharma'] },
  { name: 'phone_number', values: ['+91 98765 12345'] },
  { name: 'email', values: ['priya@example.com'] },
  { name: 'company_name', values: ['Sharma Logistics'] },
  { name: 'custom_requirement', values: ['Bulk shipment to Mumbai'] },
  { name: 'whatsapp_opt_in_consent', values: ['Yes, send me updates on WhatsApp'] }
];

const parsed = parseLeadFields(mockFieldData, 'IN');
assert.strictEqual(parsed.name, 'Priya Sharma');
assert.strictEqual(parsed.email, 'priya@example.com');
assert.strictEqual(parsed.companyName, 'Sharma Logistics');
assert.strictEqual(parsed.phone.digits, '919876512345');
assert.strictEqual(parsed.custom.custom_requirement, 'Bulk shipment to Mumbai');
assert.strictEqual(parsed.consent.answer, 'Yes, send me updates on WhatsApp');
console.log('✅ parseLeadFields Instant Form parsing passed');

console.log('🎉 All Meta Lead Integration unit tests passed successfully!');
