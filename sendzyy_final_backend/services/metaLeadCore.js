'use strict';

const Lead = require('../models/Lead');
const MetaLeadEvent = require('../models/MetaLeadEvent');

/**
 * Claims or checks an inbound Meta event in the idempotency ledger.
 * Returns the existing event document, or { status: 'processing', fresh: true } if newly claimed.
 */
async function claimEvent(tenantId, dedupeKey, type, extra = {}) {
  try {
    const prev = await MetaLeadEvent.findOneAndUpdate(
      { tenantId, dedupeKey },
      { $setOnInsert: { tenantId, dedupeKey, type, status: 'processing', ...extra } },
      { upsert: true, new: false }
    );
    return prev || { status: 'processing', fresh: true };
  } catch (e) {
    if (e.code === 11000) {
      // Race condition handled: query again
      return claimEvent(tenantId, dedupeKey, type, extra);
    }
    throw e;
  }
}

/**
 * Maintains single lead per (tenantId, mobileNumber).
 * Appends new Meta events as touchpoints on the lead.
 * Preserves the original lead's first `source` attribution.
 */
async function upsertLeadWithTouchpoint({
  tenantId,
  phone,
  invalidPhoneRaw,
  name,
  email,
  companyName,
  custom,
  touchpoint
}) {
  const snapshot = { ...touchpoint };
  const baseUpdate = {
    $push: { touchpoints: touchpoint },
    $set: { meta: snapshot }
  };

  let lead;
  if (phone) {
    lead = await Lead.findOneAndUpdate(
      { tenantId, mobileNumber: phone },
      {
        ...baseUpdate,
        $setOnInsert: {
          tenantId,
          mobileNumber: phone,
          source: 'meta_ads',
          status: 'new'
        }
      },
      { upsert: true, new: true }
    );
  } else {
    // Lead submitted without valid phone: persist with needsAttention: true so it's not lost
    lead = await Lead.create({
      tenantId,
      mobileNumber: '',
      source: 'meta_ads',
      status: 'new',
      needsAttention: true,
      invalidPhoneRaw: invalidPhoneRaw || '',
      touchpoints: [touchpoint],
      meta: snapshot
    });
  }

  // Fill empty fields without overwriting existing data
  const fill = {};
  if (!lead.name && name) fill.name = name;
  if (!lead.email && email) fill.email = email;
  if (!lead.companyName && companyName) fill.companyName = companyName;
  if (custom && Object.keys(custom).length) {
    for (const [k, v] of Object.entries(custom)) {
      fill[`metadata.${k}`] = v;
    }
  }

  if (Object.keys(fill).length) {
    lead = await Lead.findByIdAndUpdate(lead._id, { $set: fill }, { new: true });
  }

  return lead;
}

module.exports = {
  claimEvent,
  upsertLeadWithTouchpoint
};
