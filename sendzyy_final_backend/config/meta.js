'use strict';

const META_GRAPH_VERSION = process.env.META_GRAPH_VERSION || 'v26.0';
const GRAPH_BASE_URL = `https://graph.facebook.com/${META_GRAPH_VERSION}`;

const OAUTH_SCOPES = [
    'public_profile',
    'pages_show_list',
    'pages_read_engagement',
    'pages_manage_metadata',
    'pages_manage_ads',
    'leads_retrieval',
    'ads_read'
];

const LEAD_FIELDS =
    'id,created_time,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,is_organic,platform,field_data';

module.exports = {
    META_GRAPH_VERSION,
    GRAPH_BASE_URL,
    OAUTH_SCOPES,
    LEAD_FIELDS
};
