'use strict';

const { normalizePhone } = require('../utils/phoneNormalizer');

/**
 * Parses field_data array returned by Meta Graph API /{leadgen_id}
 * 
 * @param {Array} fieldData - Array of { name, values } from Meta Graph API
 * @param {string} defaultCountry - Fallback country ISO-2, e.g. 'IN'
 * @returns {Object} Parsed lead fields with normalized phone, consent, and custom answers
 */
function parseLeadFields(fieldData = [], defaultCountry = 'IN') {
  const out = {
    name: '',
    email: '',
    companyName: '',
    phone: normalizePhone('', defaultCountry),
    custom: {},
    consent: null
  };

  const getVal = f => (Array.isArray(f.values) ? f.values[0] : '') || '';
  let first = '';
  let last = '';

  for (const f of fieldData) {
    const key = (f.name || '').toLowerCase();
    const val = getVal(f);
    if (!val) continue;

    if (key === 'full_name') {
      out.name = val;
    } else if (key === 'first_name') {
      first = val;
    } else if (key === 'last_name') {
      last = val;
    } else if (key === 'email') {
      out.email = val;
    } else if (key === 'phone_number' || key === 'phone' || key === 'whatsapp_number' || key.includes('mobile')) {
      out.phone = normalizePhone(val, defaultCountry);
    } else if (key === 'company_name' || key.includes('company')) {
      out.companyName = val;
    } else if (key.includes('consent') || key.includes('opt_in') || key.includes('opt-in')) {
      out.consent = { question: f.name, answer: val };
    } else {
      out.custom[f.name] = val; // City, custom qualifying questions, etc.
    }
  }

  if (!out.name && (first || last)) {
    out.name = [first, last].filter(Boolean).join(' ');
  }

  return out;
}

module.exports = { parseLeadFields };
