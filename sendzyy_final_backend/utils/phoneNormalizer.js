'use strict';

const { parsePhoneNumberFromString, getCountryCallingCode } = require('libphonenumber-js');

/**
 * Normalizes phone numbers to WhatsApp Cloud API compatible format (E.164 digits without '+').
 * Supports all countries — uses tenant's defaultCountry for local-format numbers.
 * 
 * Strategy:
 *   1. If number has '+' or starts with '00' → parse internationally (ignore defaultCountry)
 *   2. Otherwise try parsing as-is with defaultCountry hint (libphonenumber handles local format)
 *   3. Fallback: strip non-digits, prepend calling code for defaultCountry, validate result
 *   4. Fallback 2: if already 11–15 digits (likely has country code), accept as-is
 * 
 * @param {string} raw            value from form, webhook, or CSV
 * @param {string} defaultCountry ISO-2 code from tenant settings (e.g. 'IN', 'US', 'AU')
 * @returns {{ valid: boolean, digits: string, e164: string, raw: string }}
 */
function normalizePhone(raw, defaultCountry = 'IN') {
  if (!raw) return { valid: false, digits: '', e164: '', raw: '' };
  let s = String(raw).trim();

  // Normalise 00-prefix to + (international dialling prefix)
  if (s.startsWith('00')) s = '+' + s.slice(2);

  // --- Attempt 1: Parse with libphonenumber (handles international and local formats) ---
  try {
    const p = parsePhoneNumberFromString(s, defaultCountry);
    if (p && p.isValid()) {
      return { valid: true, digits: p.number.replace('+', ''), e164: p.number, raw: s };
    }
  } catch (_) {}

  // --- Attempt 2: Strip to digits and try prepending the country calling code ---
  let digitsOnly = s.replace(/\D/g, '');

  // Strip leading 0 (common local trunk prefix in many countries)
  if (digitsOnly.startsWith('0')) digitsOnly = digitsOnly.substring(1);

  if (digitsOnly.length >= 4 && digitsOnly.length <= 13) {
    try {
      const callingCode = getCountryCallingCode(defaultCountry); // e.g. '91' for IN, '1' for US
      const withCode = callingCode + digitsOnly;
      const p2 = parsePhoneNumberFromString('+' + withCode, defaultCountry);
      if (p2 && p2.isValid()) {
        return { valid: true, digits: withCode, e164: '+' + withCode, raw: s };
      }
    } catch (_) {}
  }

  // --- Attempt 3: If already a full international length (11–15 digits), accept as-is ---
  if (digitsOnly.length >= 11 && digitsOnly.length <= 15) {
    return { valid: true, digits: digitsOnly, e164: '+' + digitsOnly, raw: s };
  }

  return { valid: false, digits: '', e164: '', raw: s };
}

/**
 * Helper returning only normalized digits (or empty string if invalid).
 * Drop-in replacement for old normalizePhoneNumber — backward compatible.
 */
function normalizePhoneNumber(raw, defaultCountry = 'IN') {
  const result = normalizePhone(raw, defaultCountry);
  return result.digits;
}

module.exports = { normalizePhone, normalizePhoneNumber };

