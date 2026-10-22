'use strict';

const axios = require('axios');
const MetaConnection = require('../models/MetaConnection');
const MetaPageConnection = require('../models/MetaPageConnection');
const { GRAPH_BASE_URL } = require('../config/meta');

const RATE_LIMIT_CODES = [4, 17, 32, 613];

/**
 * Sanitizes URLs to remove sensitive tokens from logs
 */
function sanitizeUrl(url) {
  if (!url) return '';
  return url.replace(/access_token=[^&]+/g, 'access_token=REDACTED');
}

/**
 * Wrapper for Meta Graph API GET requests
 */
async function graphGet(endpoint, params = {}, connection = null) {
  const url = `${GRAPH_BASE_URL}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;
  try {
    const response = await axios.get(url, { params });
    return response.data;
  } catch (err) {
    await handleMetaApiError(connection, err);
  }
}

/**
 * Wrapper for Meta Graph API POST requests
 */
async function graphPost(endpoint, data = {}, params = {}, connection = null) {
  const url = `${GRAPH_BASE_URL}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;
  try {
    const response = await axios.post(url, data, { params });
    return response.data;
  } catch (err) {
    await handleMetaApiError(connection, err);
  }
}

/**
 * Centralized Meta API Error Handling
 */
async function handleMetaApiError(connection, err) {
  const e = err.response?.data?.error || {};
  const errorMessage = (e.message || err.message || '').slice(0, 300);
  const info = { code: e.code, message: errorMessage, at: new Date() };

  console.error(`[MetaGraphClient] Error ${e.code || 'unknown'}: ${errorMessage} at ${sanitizeUrl(err.config?.url)}`);

  // Error 190: Token expired, invalid or revoked
  if (e.code === 190) {
    if (connection) {
      if (connection.connectionId) {
        // MetaPageConnection
        await MetaPageConnection.updateMany(
          { connectionId: connection.connectionId },
          { status: 'needs_reauth', lastError: info }
        );
        await MetaConnection.updateOne(
          { _id: connection.connectionId },
          { status: 'needs_reauth', lastError: info }
        );
      } else {
        // MetaConnection
        await MetaConnection.updateOne(
          { _id: connection._id },
          { status: 'needs_reauth', lastError: info }
        );
      }
    }
    const tokenErr = new Error(`Meta token invalid or expired (code 190)`);
    tokenErr.code = 190;
    tokenErr.isUnrecoverable = true;
    throw tokenErr;
  }

  // Rate limits
  if (RATE_LIMIT_CODES.includes(e.code)) {
    const rateErr = new Error(`Meta rate limit encountered (code ${e.code})`);
    rateErr.code = e.code;
    rateErr.isRateLimit = true;
    throw rateErr;
  }

  // Permissions or Object Access (Leads Access Manager missing etc)
  if (e.code === 10 || e.code === 200 || e.code === 100) {
    if (connection?.connectionId) {
      await MetaPageConnection.updateOne(
        { _id: connection._id },
        { status: 'needs_attention', lastError: info }
      );
    }
    const permErr = new Error(`Meta permission / leads access issue (code ${e.code}): ${errorMessage}`);
    permErr.code = e.code;
    permErr.isUnrecoverable = true;
    throw permErr;
  }

  throw err;
}

module.exports = {
  graphGet,
  graphPost,
  handleMetaApiError,
  sanitizeUrl
};
