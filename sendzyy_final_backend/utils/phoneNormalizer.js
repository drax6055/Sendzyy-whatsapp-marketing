'use strict';

const { parsePhoneNumberFromString } = require('libphonenumber-js');

/**
 * Normalizes phone numbers to WhatsApp Cloud API compatible format (E.164 digits without '+').
 * 
 * @param {string} raw            value from the form or webhook
 * @param {string} defaultCountry ISO-2 code from tenant settings (e.g. 'IN')
 * @returns {{ valid: boolean, digits: string, e164: string, raw: string }}
 */
function normalizePhone(raw, defaultCountry = 'IN') {
  if (!raw) return { valid: false, digits: '', e164: '', raw: '' };
  let s = String(raw).trim();
  if (s.startsWith('00')) s = '+' + s.slice(2);

  try {
    const p = parsePhoneNumberFromString(s, defaultCountry);
    if (p && p.isValid()) {
      return { valid: true, digits: p.number.replace('+', ''), e164: p.number, raw: s };
    }
  } catch (_) {}

  // Fallback for standard 10-digit Indian numbers or leading zero
  let digitsOnly = s.replace(/\D/g, '');
  if (digitsOnly.startsWith('0')) digitsOnly = digitsOnly.substring(1);
  if (digitsOnly.length === 10 && defaultCountry === 'IN') {
    digitsOnly = '91' + digitsOnly;
    return { valid: true, digits: digitsOnly, e164: '+' + digitsOnly, raw: s };
  } else if (digitsOnly.length >= 11 && digitsOnly.length <= 15) {
    return { valid: true, digits: digitsOnly, e164: '+' + digitsOnly, raw: s };
  }

  return { valid: false, digits: '', e164: '', raw: s };
}

/**
 * Helper returning only normalized digits (or empty string if invalid)
 */
function normalizePhoneNumber(raw, defaultCountry = 'IN') {
  const result = normalizePhone(raw, defaultCountry);
  return result.digits;
}

module.exports = { normalizePhone, normalizePhoneNumber };
