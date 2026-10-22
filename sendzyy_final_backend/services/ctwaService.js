'use strict';

const { claimEvent, upsertLeadWithTouchpoint } = require('./metaLeadCore');
const MetaLeadEvent = require('../models/MetaLeadEvent');
const MetaConnection = require('../models/MetaConnection');
const MetaCache = require('../models/MetaCache');
const Lead = require('../models/Lead');
const { decryptToken } = require('../utils/cryptoUtils');
const { graphGet } = require('./metaGraphClient');
const { evaluateMetaTriggers } = require('./metaTriggers');

const withTimeout = (p, ms) =>
  Promise.race([p, new Promise(r => setTimeout(() => r(null), ms))]);

/**
 * Looks up ad and campaign names from Marketing API using User Token (requires ads_read scope)
 */
async function lookupAd(tenantId, adId) {
  if (!adId) return null;
  const key = `ad:${tenantId}:${adId}`;
  try {
    const hit = await MetaCache.findOne({ key, expiresAt: { $gt: new Date() } });
    if (hit && hit.value) return hit.value;

    const conn = await MetaConnection.findOne({ tenantId, status: 'active' });
    if (!conn) return null;

    const token = decryptToken(conn.userAccessToken);
    const ad = await graphGet(
      `/${adId}`,
      { fields: 'name,campaign{id,name},adset{id,name}', access_token: token },
      conn
    );

    if (ad) {
      const value = {
        adName: ad.name || '',
        campaignId: ad.campaign?.id || '',
        campaignName: ad.campaign?.name || '',
        adsetId: ad.adset?.id || '',
        adsetName: ad.adset?.name || ''
      };
      await MetaCache.updateOne(
        { key },
        { value, expiresAt: new Date(Date.now() + 864e5) },
        { upsert: true }
      );
      return value;
    }
  } catch (err) {
    console.warn(`[CTWA] Could not lookup ad ${adId}:`, err.message);
  }
  return null;
}

/**
 * Handles inbound WhatsApp message containing a CTWA referral.
 * Called from WhatsApp webhook handler.
 */
async function handleCtwaReferralIfPresent({ tenantId, message, contact }) {
  const ref = message?.referral;
  if (!ref) return null; // Not a CTWA click

  const dedupeKey = `ctwa:${message.id}`;
  const ev = await claimEvent(tenantId, dedupeKey, 'ctwa');
  if (ev.status === 'done') return null;

  const phone = String(message.from || '').replace(/\D/g, '');
  const ad = ref.source_id
    ? await withTimeout(lookupAd(tenantId, ref.source_id).catch(() => null), 2500)
    : null;

  const touchpoint = {
    dedupeKey,
    source: 'meta_ads',
    adType: 'ctwa',
    sourceType: ref.source_type || 'ad',
    platform: 'unknown',
    adId: ref.source_id || '',
    adName: ad?.adName || '',
    adsetId: ad?.adsetId || '',
    adsetName: ad?.adsetName || '',
    campaignId: ad?.campaignId || '',
    campaignName: ad?.campaignName || '',
    ctwaClid: ref.ctwa_clid || '',
    headline: ref.headline || '',
    body: ref.body || '',
    sourceUrl: ref.source_url || '',
    at: new Date(Number(message.timestamp) * 1000 || Date.now())
  };

  const lead = await upsertLeadWithTouchpoint({
    tenantId,
    phone,
    name: contact?.profile?.name || '',
    touchpoint
  });

  await MetaLeadEvent.updateOne(
    { tenantId, dedupeKey },
    { status: 'lead_saved', leadId: lead._id, rawPayload: ref }
  );

  // If ad details were not available immediately, schedule asynchronous background lookup
  if (!ad && ref.source_id) {
    setImmediate(async () => {
      try {
        await enrichCtwaAd({ tenantId, leadId: lead._id, dedupeKey, adId: ref.source_id });
      } catch (_) {}
    });
  }

  await evaluateMetaTriggers({ tenantId, lead, touchpoint });
  await MetaLeadEvent.updateOne({ tenantId, dedupeKey }, { status: 'done' });
  return lead;
}

/**
 * Enriches existing lead with resolved ad and campaign metadata
 */
async function enrichCtwaAd({ tenantId, leadId, dedupeKey, adId }) {
  const ad = await lookupAd(tenantId, adId);
  if (!ad) return;

  await Lead.updateOne(
    { _id: leadId, 'touchpoints.dedupeKey': dedupeKey },
    {
      $set: {
        'touchpoints.$.adName': ad.adName,
        'touchpoints.$.adsetId': ad.adsetId,
        'touchpoints.$.adsetName': ad.adsetName,
        'touchpoints.$.campaignId': ad.campaignId,
        'touchpoints.$.campaignName': ad.campaignName,
        'meta.adName': ad.adName,
        'meta.campaignId': ad.campaignId,
        'meta.campaignName': ad.campaignName,
        'meta.adsetId': ad.adsetId,
        'meta.adsetName': ad.adsetName
      }
    }
  );
  console.log(`[CTWA] Enriched lead ${leadId} with campaign "${ad.campaignName}" / ad "${ad.adName}"`);
}

module.exports = {
  handleCtwaReferralIfPresent,
  enrichCtwaAd,
  lookupAd
};
