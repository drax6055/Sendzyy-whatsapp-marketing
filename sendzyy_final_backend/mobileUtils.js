/**
 * Mobile number utilities for lead ingestion.
 * Requirements: 1.7, 12.3, 12.4
 *
 * NOTE: normaliseMobileNumber now accepts an optional defaultCountry (ISO-2) parameter.
 * Existing callers that pass no second argument default to 'IN' (India) — no behaviour change.
 */

const { normalizePhone } = require('./utils/phoneNormalizer');

/**
 * Normalise a raw mobile number string using country-aware phone parsing.
 * If defaultCountry is 'IN' and the number is 10 digits, prepends '91' (same as before).
 * For other countries, prepends their calling code when a local-format number is detected.
 *
 * @param {string|null|undefined} raw
 * @param {string} defaultCountry ISO-2 country code (default: 'IN')
 * @returns {string} E.164 digits without '+', or '' if invalid/empty
 */
function normaliseMobileNumber(raw, defaultCountry = 'IN') {
  if (raw == null || raw === '') return '';
  return normalizePhone(String(raw), defaultCountry).digits;
}

/**
 * Validate a normalised mobile number.
 * Returns true if the number has between 7 and 15 digits (inclusive).
 *
 * @param {string} normalised
 * @returns {boolean}
 */
function validateMobileNumber(normalised) {
  if (!normalised) return false;
  return normalised.length >= 7 && normalised.length <= 15;
}

module.exports = { normaliseMobileNumber, validateMobileNumber };
