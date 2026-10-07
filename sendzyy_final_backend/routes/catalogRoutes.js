/**
 * catalogRoutes.js
 * ─────────────────────────────────────────────────────────────────────────────
 * WhatsApp Catalog API routes for Sendzyy
 * Uses: Meta Commerce API + Meta WhatsApp Cloud API (official endpoints)
 * Auth: JWT authenticate middleware (tenant-scoped, same pattern as instagramRoutes)
 * Storage: Amazon S3 for product images (multer-s3)
 * ─────────────────────────────────────────────────────────────────────────────
 */

const express = require('express');
const router = express.Router();
const axios = require('axios');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const { S3Client, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const multerS3 = require('multer-s3');

const Catalog = require('../models/Catalog');
const CatalogProduct = require('../models/CatalogProduct');
const CatalogOrder = require('../models/CatalogOrder');

const META_GRAPH_URL = 'https://graph.facebook.com/v22.0';

// ── Helper: get Tenant model from app ────────────────────────────────────────
const getTenantModel = (req) => req.app.get('TenantModel') || require('mongoose').model('Tenant');

// ── Auth Middleware ───────────────────────────────────────────────────────────
const authenticate = (req, res, next) => {
    const token = req.headers['authorization']?.split(' ')[1] || req.query.token;
    if (!token) return res.sendStatus(401);
    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        if (!user.tenantId) return res.status(401).json({ error: 'Invalid session' });
        req.user = user;
        next();
    });
};

// ── S3 Client setup ───────────────────────────────────────────────────────────
const s3Client = new S3Client({
    region: process.env.AWS_REGION || 'ap-south-1',
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
    },
});

const S3_BUCKET = process.env.AWS_S3_BUCKET || 'sendzyy-catalog-images';

// ── Multer-S3 Storage ─────────────────────────────────────────────────────────
const s3Storage = multerS3({
    s3: s3Client,
    bucket: S3_BUCKET,
    acl: 'public-read',
    contentType: multerS3.AUTO_CONTENT_TYPE,
    key: (req, file, cb) => {
        const ext = file.originalname.split('.').pop();
        const filename = `catalog-products/${req.user?.tenantId || 'unknown'}/${uuidv4()}.${ext}`;
        cb(null, filename);
    },
});

const uploadProductImage = multer({
    storage: s3Storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only image files are allowed'), false);
        }
    },
}).single('image');

// ── Helper: get tenant WhatsApp config ───────────────────────────────────────
async function getTenantConfig(req) {
    const Tenant = getTenantModel(req);
    const tenant = await Tenant.findById(req.user.tenantId).lean();
    if (!tenant?.whatsappConfig?.accessToken) {
        console.error('[CATALOG CONFIG] ❌ WhatsApp not configured for tenantId:', req.user.tenantId);
        throw new Error('WhatsApp not configured for this account');
    }
    const cfg = tenant.whatsappConfig;
    const maskedToken = cfg.accessToken ? `${cfg.accessToken.substring(0, 10)}...${cfg.accessToken.slice(-6)}` : 'MISSING';
    console.log('[CATALOG CONFIG] ✅ Tenant config loaded:', JSON.stringify({
        tenantId: req.user.tenantId,
        phoneNumberId: cfg.phoneNumberId || 'NOT SET',
        businessAccountId: cfg.businessAccountId || 'NOT SET',
        businessPortfolioId: cfg.businessPortfolioId || 'NOT SET',
        businessId: cfg.businessId || 'NOT SET',
        accessToken: maskedToken,
    }));
    return cfg;
}

// ── Helper: Meta API call ─────────────────────────────────────────────────────
async function metaGet(path, accessToken, params = {}) {
    const url = `${META_GRAPH_URL}/${path}`;
    console.log(`[META API] ➡️  GET ${url}`, JSON.stringify({ params: Object.keys(params) }));
    try {
        const response = await axios.get(url, {
            params: { ...params, access_token: accessToken },
        });
        console.log(`[META API] ✅ GET ${path} → status: ${response.status}`);
        return response.data;
    } catch (err) {
        console.error(`[META API] ❌ GET ${path} → status: ${err.response?.status}`, JSON.stringify(err.response?.data?.error || err.message));
        throw err;
    }
}

async function metaPost(path, accessToken, data) {
    const url = `${META_GRAPH_URL}/${path}`;
    console.log(`[META API] ➡️  POST ${url}`, JSON.stringify({ body: data }));
    try {
        const response = await axios.post(url, data, {
            params: { access_token: accessToken },
            headers: { 'Content-Type': 'application/json' },
        });
        console.log(`[META API] ✅ POST ${path} → status: ${response.status}`, JSON.stringify(response.data));
        return response.data;
    } catch (err) {
        console.error(`[META API] ❌ POST ${path} → status: ${err.response?.status}`, JSON.stringify(err.response?.data || err.message));
        throw err;
    }
}

async function metaDelete(path, accessToken) {
    const url = `${META_GRAPH_URL}/${path}`;
    console.log(`[META API] ➡️  DELETE ${url}`);
    try {
        const response = await axios.delete(url, {
            params: { access_token: accessToken },
        });
        console.log(`[META API] ✅ DELETE ${path} → status: ${response.status}`);
        return response.data;
    } catch (err) {
        console.error(`[META API] ❌ DELETE ${path} → status: ${err.response?.status}`, JSON.stringify(err.response?.data?.error || err.message));
        throw err;
    }
}

async function linkCatalogToWaba(wabaId, catalogId, accessToken) {
    const url = `${META_GRAPH_URL}/${wabaId}/product_catalogs`;
    console.log(`[META API] ➡️  POST ${url} (linking catalog ${catalogId} to WABA ${wabaId})`);
    const formParams = new URLSearchParams();
    formParams.append('catalog_id', catalogId);

    const response = await axios.post(url, formParams, {
        params: {
            catalog_id: catalogId,
            access_token: accessToken,
        },
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
    });
    console.log(`[META API] ✅ POST link catalog → status: ${response.status}`, JSON.stringify(response.data));
    return response.data;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATALOG ENDPOINTS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /api/catalog/list
 * List all catalogs linked to this tenant's WABA
 */
router.get('/list', authenticate, async (req, res) => {
    console.log('\n══════════════════════════════════════════════════════════');
    console.log('[CATALOG LIST] 📋 Request received from tenantId:', req.user.tenantId);
    console.log('══════════════════════════════════════════════════════════');
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;

        // Fetch from Meta
        let metaCatalogs = [];
        if (config.businessAccountId) {
            console.log('[CATALOG LIST] Fetching catalogs from Meta WABA:', config.businessAccountId);
            try {
                // Call product_catalogs without invalid fields
                const metaResp = await metaGet(
                    `${config.businessAccountId}/product_catalogs`,
                    config.accessToken
                );
                metaCatalogs = metaResp.data || [];
                console.log(`[CATALOG LIST] ✅ Meta returned ${metaCatalogs.length} catalog(s):`, metaCatalogs.map(c => ({ id: c.catalog_id || c.id, name: c.name })));
            } catch (metaErr) {
                console.warn('[CATALOG LIST] ⚠️  Meta list error (using DB only):', metaErr.response?.data?.error || metaErr.message);
            }
        } else {
            console.warn('[CATALOG LIST] ⚠️  No businessAccountId configured — skipping Meta fetch');
        }

        // Also fetch from our DB
        const dbCatalogs = await Catalog.find({ tenantId }).lean();
        console.log(`[CATALOG LIST] DB has ${dbCatalogs.length} catalog(s)`);

        // Merge: prefer Meta data, supplement with DB
        const dbMap = {};
        dbCatalogs.forEach(c => { dbMap[c.catalogId] = c; });

        const merged = metaCatalogs.map(mc => {
            const catId = mc.catalog_id || mc.id;
            return {
                catalogId: catId,
                catalogName: mc.name || dbMap[catId]?.catalogName || catId,
                productCount: mc.product_count || dbMap[catId]?.productCount || 0,
                verticalType: mc.vertical || dbMap[catId]?.verticalType || 'commerce',
                isLinked: true,
                _dbId: dbMap[catId]?._id,
            };
        });

        // Add any DB-only catalogs (recently created but not yet in WABA product_catalogs)
        dbCatalogs.forEach(dc => {
            if (!merged.find(m => m.catalogId === dc.catalogId)) {
                merged.push({
                    catalogId: dc.catalogId,
                    catalogName: dc.catalogName,
                    productCount: dc.productCount,
                    verticalType: dc.verticalType,
                    isLinked: dc.isLinked,
                    _dbId: dc._id,
                });
            }
        });

        // Upsert DB records for any Meta-linked catalogs we haven't stored yet
        for (const mc of metaCatalogs) {
            const catId = mc.catalog_id || mc.id;
            if (catId) {
                await Catalog.findOneAndUpdate(
                    { tenantId, catalogId: catId },
                    {
                        $set: {
                            catalogName: mc.name || catId,
                            verticalType: mc.vertical || 'commerce',
                            productCount: mc.product_count || 0,
                            isLinked: true,
                            linkedToWabaId: config.businessAccountId || '',
                        }
                    },
                    { upsert: true, new: true }
                );
            }
        }

        console.log(`[CATALOG LIST] ✅ Returning ${merged.length} total catalog(s)`);
        return res.json({ success: true, catalogs: merged });
    } catch (err) {
        console.error('[CATALOG LIST] ❌ Error:', err.response?.data || err.message);
        return res.status(500).json({ error: err.message });
    }
});

/**
 * POST /api/catalog/create
 * Create a new catalog via Meta API under the tenant's business portfolio
 * Body: { name, verticalType? }
 */
router.post('/create', authenticate, async (req, res) => {
    console.log('\n══════════════════════════════════════════════════════════');
    console.log('[CATALOG CREATE] 🆕 Request received');
    console.log('[CATALOG CREATE] Body:', JSON.stringify(req.body));
    console.log('══════════════════════════════════════════════════════════');
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { name, verticalType = 'commerce' } = req.body;

        if (!name) return res.status(400).json({ error: 'Catalog name is required' });

        let businessId = config.businessPortfolioId || config.businessId;

        // Auto-fix: If businessId equals WABA ID, that cannot own catalogs on Meta
        if (businessId && businessId === config.businessAccountId) {
            console.warn('[CATALOG CREATE] ⚠️ businessPortfolioId matches WABA ID — resetting to auto-resolve actual Business Manager ID.');
            businessId = null;
        }

        console.log('[CATALOG CREATE] Step 1 — Business ID from config:', businessId || 'NOT FOUND in config');
        console.log('[CATALOG CREATE]   → businessPortfolioId:', config.businessPortfolioId || 'NOT SET');
        console.log('[CATALOG CREATE]   → businessId:', config.businessId || 'NOT SET');
        console.log('[CATALOG CREATE]   → businessAccountId (WABA):', config.businessAccountId || 'NOT SET');

        // Auto-resolve Meta Business ID from WABA if not set directly in config
        if (!businessId && config.businessAccountId) {
            console.log('[CATALOG CREATE] Step 2 — Auto-resolving Business ID from WABA...');
            try {
                const wabaInfo = await metaGet(config.businessAccountId, config.accessToken, {
                    fields: 'owner_business_info,on_behalf_of_business_info'
                });
                console.log('[CATALOG CREATE] WABA info response:', JSON.stringify(wabaInfo));
                businessId = wabaInfo.owner_business_info?.id 
                    || wabaInfo.on_behalf_of_business_info?.id;
                console.log('[CATALOG CREATE] ✅ Resolved Business ID:', businessId);
            } catch (wabaErr) {
                console.error('[CATALOG CREATE] ❌ Failed to resolve Business ID from WABA:', 
                    JSON.stringify(wabaErr.response?.data?.error || wabaErr.message));
            }
        }

        if (!businessId) {
            console.warn('[CATALOG CREATE] ⚠️  No Business ID available — will create local-only catalog');
        }

        let newCatalogId = '';
        let isLinked = false;

        // Attempt creation on Meta if businessId is available
        if (businessId) {
            console.log(`[CATALOG CREATE] Step 3 — Creating catalog on Meta...`);
            console.log(`[CATALOG CREATE]   → Endpoint: POST ${META_GRAPH_URL}/${businessId}/owned_product_catalogs`);
            console.log(`[CATALOG CREATE]   → Payload: { name: "${name}", vertical: "${verticalType}" }`);
            try {
                const formParams = new URLSearchParams();
                formParams.append('name', name);
                formParams.append('vertical', verticalType);

                const metaResp = await axios.post(
                    `${META_GRAPH_URL}/${businessId}/owned_product_catalogs`,
                    formParams,
                    {
                        params: { access_token: config.accessToken },
                        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    }
                );
                newCatalogId = metaResp.data?.id || '';
                console.log(`[CATALOG CREATE] ✅ Meta catalog created! ID: ${newCatalogId}`);
            } catch (metaErr) {
                const metaError = metaErr.response?.data?.error;
                console.error('[CATALOG CREATE] ❌ Meta API creation FAILED!');
                console.error('[CATALOG CREATE]   → Error Code:', metaError?.code);
                console.error('[CATALOG CREATE]   → Error Type:', metaError?.type);
                console.error('[CATALOG CREATE]   → Error Message:', metaError?.message || metaErr.message);
                console.error('[CATALOG CREATE]   → Error Subcode:', metaError?.error_subcode);
                console.error('[CATALOG CREATE]   → Full Error:', JSON.stringify(metaErr.response?.data || metaErr.message));
                if (metaError?.code === 100 || metaError?.message?.includes('does not exist')) {
                    console.error(`[CATALOG CREATE] 💡 HINT: Business ID "${businessId}" appears invalid or token lacks catalog_management.`);
                    console.error(`[CATALOG CREATE] 💡 Make sure this is the Meta Business Manager ID (not WABA ID).`);
                    console.error(`[CATALOG CREATE] 💡 Find it at: https://business.facebook.com/settings > Business Info`);
                }
            }
        }

        // If Meta creation failed or Business ID is unavailable, generate a local Sendzyy catalog ID
        if (!newCatalogId) {
            newCatalogId = `cat_${uuidv4().substring(0, 12)}`;
            console.log(`[CATALOG CREATE] Step 4 — Using local catalog ID: ${newCatalogId}`);
        } else if (config.businessAccountId) {
            // Auto-link newly created Meta catalog to WABA
            console.log(`[CATALOG CREATE] Step 4 — Auto-linking catalog ${newCatalogId} to WABA ${config.businessAccountId}...`);
            try {
                await linkCatalogToWaba(config.businessAccountId, newCatalogId, config.accessToken);
                isLinked = true;
                console.log('[CATALOG CREATE] ✅ Auto-linked to WABA successfully');
            } catch (linkErr) {
                console.error('[CATALOG CREATE] ⚠️  Auto-link to WABA failed:', JSON.stringify(linkErr.response?.data || linkErr.message));
            }
        }

        // Save to DB
        console.log('[CATALOG CREATE] Step 5 — Saving to DB...');
        const catalog = await Catalog.create({
            tenantId,
            catalogId: newCatalogId,
            catalogName: name,
            verticalType,
            isLinked,
            linkedToWabaId: isLinked ? config.businessAccountId : '',
        });
        console.log('[CATALOG CREATE] ✅ Saved to DB. Final result:', JSON.stringify({ catalogId: newCatalogId, catalogName: name, isLinked }));

        return res.json({ success: true, catalog: { catalogId: newCatalogId, catalogName: name, isLinked } });
    } catch (err) {
        console.error('[CATALOG CREATE] ❌ UNHANDLED ERROR:', err.response?.data || err.message);
        console.error('[CATALOG CREATE] Stack:', err.stack);
        return res.status(500).json({ error: err.response?.data?.error?.message || err.message });
    }
});

/**
 * POST /api/catalog/link
 * Link an existing Meta catalog to the tenant's WABA
 * Body: { catalogId, catalogName? }
 */
router.post('/link', authenticate, async (req, res) => {
    console.log('\n══════════════════════════════════════════════════════════');
    console.log('[CATALOG LINK] 🔗 Request received');
    console.log('[CATALOG LINK] Body:', JSON.stringify(req.body));
    console.log('══════════════════════════════════════════════════════════');
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { catalogId, catalogName = '' } = req.body;

        if (!catalogId) return res.status(400).json({ error: 'catalogId is required' });
        if (!config.businessAccountId) {
            console.error('[CATALOG LINK] ❌ WABA ID (businessAccountId) not configured for this tenant');
            return res.status(400).json({ error: 'WABA ID not configured' });
        }

        // Link via Meta API: POST /{WABA_ID}/product_catalogs with catalog_id
        console.log('[CATALOG LINK] Step 1 — Linking catalog to WABA via Meta API...');
        console.log(`[CATALOG LINK]   → Endpoint: POST ${META_GRAPH_URL}/${config.businessAccountId}/product_catalogs`);
        console.log(`[CATALOG LINK]   → Catalog ID: "${catalogId}"`);
        console.log(`[CATALOG LINK]   → WABA ID: ${config.businessAccountId}`);
        console.log(`[CATALOG LINK]   → Required permissions: whatsapp_business_management, catalog_management`);

        let isMetaLinked = false;
        let linkWarning = null;
        let resolvedName = catalogName;

        // Step 1a: Pre-check if catalog is ALREADY connected to this WABA on Meta
        try {
            console.log('[CATALOG LINK] Checking existing Meta linked catalogs on WABA...');
            const existingMeta = await metaGet(`${config.businessAccountId}/product_catalogs`, config.accessToken);
            const found = (existingMeta.data || []).find(c => (c.catalog_id || c.id) === catalogId);
            if (found) {
                console.log(`[CATALOG LINK] ✅ Catalog ${catalogId} is ALREADY connected to WABA on Meta! Name: "${found.name}"`);
                isMetaLinked = true;
                if (!resolvedName && found.name) resolvedName = found.name;
            }
        } catch (checkErr) {
            console.warn('[CATALOG LINK] ⚠️ Pre-check of Meta catalogs skipped:', checkErr.response?.data?.error?.message || checkErr.message);
        }

        // Step 1b: If not already linked, link via Meta API
        if (!isMetaLinked) {
            try {
                await linkCatalogToWaba(config.businessAccountId, catalogId, config.accessToken);
                isMetaLinked = true;
                console.log(`[CATALOG LINK] ✅ Successfully linked catalog ${catalogId} to WABA!`);
            } catch (linkErr) {
                const metaError = linkErr.response?.data?.error;
                const errMsg = metaError?.message || linkErr.message;
                const subcode = metaError?.error_subcode;
                const code = metaError?.code;

                console.error('[CATALOG LINK] ❌ Meta API link call response:');
                console.error('[CATALOG LINK]   → Error Code:', code);
                console.error('[CATALOG LINK]   → Error Subcode:', subcode);
                console.error('[CATALOG LINK]   → Error Message:', errMsg);

                // Check for duplicate / already connected subcodes & codes
                const isAlreadyLinked = 
                    subcode === 2388099 || 
                    subcode === 2388044 || 
                    code === 804 ||
                    errMsg?.toLowerCase().includes('already') ||
                    errMsg?.toLowerCase().includes('exists') ||
                    errMsg?.toLowerCase().includes('duplicate') ||
                    errMsg?.toLowerCase().includes('conflict');

                if (isAlreadyLinked) {
                    console.log('[CATALOG LINK] ℹ️ Catalog is already connected to this WABA on Meta. Treating as linked!');
                    isMetaLinked = true;
                } else {
                    linkWarning = errMsg;
                    console.warn(`[CATALOG LINK] ⚠️ Meta API link issue: ${errMsg}. Catalog will still be saved to Sendzyy.`);
                }
            }
        }

        // Fetch catalog name from Meta if not provided
        console.log('[CATALOG LINK] Step 2 — Resolving catalog name...');
        if (!resolvedName) {
            try {
                const info = await metaGet(catalogId, config.accessToken, { fields: 'name' });
                resolvedName = info.name || catalogId;
                console.log(`[CATALOG LINK] ✅ Resolved name from Meta: "${resolvedName}"`);
            } catch (nameErr) {
                resolvedName = catalogId;
                console.warn(`[CATALOG LINK] ⚠️  Could not resolve catalog name from Meta, using ID: ${catalogId}`);
            }
        } else {
            console.log(`[CATALOG LINK] Using provided name: "${resolvedName}"`);
        }

        // Save or update in DB
        console.log('[CATALOG LINK] Step 3 — Saving to DB...');
        const catalog = await Catalog.findOneAndUpdate(
            { tenantId, catalogId },
            {
                $set: {
                    catalogName: resolvedName,
                    isLinked: isMetaLinked,
                    linkedToWabaId: isMetaLinked ? config.businessAccountId : '',
                }
            },
            { upsert: true, new: true }
        );
        console.log('[CATALOG LINK] ✅ Done! Catalog linked and saved:', JSON.stringify({ catalogId, catalogName: resolvedName, isLinked: isMetaLinked }));

        return res.json({
            success: true,
            catalogId,
            catalogName: resolvedName,
            isLinked: isMetaLinked,
            warning: linkWarning,
            catalog: {
                catalogId,
                catalogName: resolvedName,
                isLinked: isMetaLinked,
                _dbId: catalog._id,
            },
        });
    } catch (err) {
        console.error('[CATALOG LINK] ❌ UNHANDLED ERROR:', err.response?.data || err.message);
        console.error('[CATALOG LINK] Stack:', err.stack);
        return res.status(500).json({ error: err.response?.data?.error?.message || err.message });
    }
});

/**
 * DELETE /api/catalog/:catalogId/unlink
 * Unlink a catalog from tenant's WABA
 */
router.delete('/:catalogId/unlink', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { catalogId } = req.params;

        if (config.businessAccountId) {
            try {
                await metaDelete(
                    `${config.businessAccountId}/product_catalogs?catalog_id=${catalogId}`,
                    config.accessToken
                );
            } catch (metaErr) {
                console.warn('[CATALOG UNLINK] Meta error:', metaErr.response?.data || metaErr.message);
            }
        }

        await Catalog.findOneAndUpdate(
            { tenantId, catalogId },
            { $set: { isLinked: false, linkedToWabaId: '' } }
        );

        return res.json({ success: true });
    } catch (err) {
        console.error('[CATALOG UNLINK]', err.response?.data || err.message);
        return res.status(500).json({ error: err.message });
    }
});

/**
 * DELETE /api/catalog/:catalogId
 * Delete a catalog completely from Sendzyy (and unlink from Meta if linked)
 */
router.delete('/:catalogId', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { catalogId } = req.params;

        if (config.businessAccountId) {
            try {
                await metaDelete(
                    `${config.businessAccountId}/product_catalogs?catalog_id=${catalogId}`,
                    config.accessToken
                );
            } catch (metaErr) {
                console.warn('[CATALOG DELETE] Meta unlink error:', metaErr.response?.data || metaErr.message);
            }
        }

        await Promise.all([
            Catalog.findOneAndDelete({ tenantId, catalogId }),
            CatalogProduct.deleteMany({ tenantId, catalogId }),
        ]);

        console.log(`[CATALOG DELETE] ✅ Catalog ${catalogId} deleted from DB`);
        return res.json({ success: true });
    } catch (err) {
        console.error('[CATALOG DELETE]', err.response?.data || err.message);
        return res.status(500).json({ error: err.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
//  PRODUCT ENDPOINTS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /api/catalog/:catalogId/products
 * Fetch products for a catalog (from our DB, with optional Meta sync)
 */
router.get('/:catalogId/products', authenticate, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const { catalogId } = req.params;
        const { page = 1, limit = 50 } = req.query;

        const skip = (parseInt(page) - 1) * parseInt(limit);

        const [products, total] = await Promise.all([
            CatalogProduct.find({ tenantId, catalogId })
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(parseInt(limit))
                .lean(),
            CatalogProduct.countDocuments({ tenantId, catalogId }),
        ]);

        return res.json({ success: true, products, total, page: parseInt(page), limit: parseInt(limit) });
    } catch (err) {
        console.error('[PRODUCTS GET]', err.message);
        return res.status(500).json({ error: err.message });
    }
});

/**
 * POST /api/catalog/:catalogId/products
 * Create a single product in Meta catalog + save to DB
 * Body: { retailerId, name, description, price, currency, imageUrl, availability, condition, link, brand, category, salePrice }
 */
router.post('/:catalogId/products', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { catalogId } = req.params;
        const {
            retailerId,
            name,
            description = '',
            price,
            currency = 'INR',
            imageUrl,
            availability = 'in stock',
            condition = 'new',
            link = '',
            brand = '',
            category = '',
            salePrice,
        } = req.body;

        // Validation
        if (!retailerId || !name || !price || !imageUrl) {
            return res.status(400).json({ error: 'retailerId, name, price, and imageUrl are required' });
        }

        // Check retailer ID uniqueness within catalog
        const existing = await CatalogProduct.findOne({ tenantId, catalogId, retailerId });
        if (existing) {
            return res.status(400).json({ error: `A product with retailer ID "${retailerId}" already exists in this catalog` });
        }

        // Push to Meta Commerce API
        const metaProductData = {
            retailer_id: retailerId,
            name,
            description,
            price: Math.round(parseFloat(price) * 100), // Meta expects price in minor units (paise for INR)
            currency,
            image_url: imageUrl,
            availability,
            condition,
            ...(link && { url: link }),
            ...(brand && { brand }),
            ...(category && { category }),
            ...(salePrice && { sale_price: Math.round(parseFloat(salePrice) * 100) }),
        };

        let productId = '';
        try {
            const metaResp = await metaPost(`${catalogId}/products`, config.accessToken, metaProductData);
            productId = metaResp.id || '';
        } catch (metaErr) {
            console.warn('[PRODUCT CREATE] Meta push failed:', metaErr.response?.data || metaErr.message);
            // Continue — save locally even if Meta push fails
        }

        // Save to DB
        const product = await CatalogProduct.create({
            tenantId,
            catalogId,
            productId,
            retailerId,
            name,
            description,
            price: parseFloat(price),
            currency,
            imageUrl,
            availability,
            condition,
            link,
            brand,
            category,
            salePrice: salePrice ? parseFloat(salePrice) : null,
            isSynced: !!productId,
            metaSyncedAt: productId ? new Date() : null,
        });

        // Update product count on catalog
        await Catalog.findOneAndUpdate(
            { tenantId, catalogId },
            { $inc: { productCount: 1 } }
        );

        return res.status(201).json({ success: true, product });
    } catch (err) {
        console.error('[PRODUCT CREATE]', err.response?.data || err.message);
        return res.status(500).json({ error: err.response?.data?.error?.message || err.message });
    }
});

/**
 * PUT /api/catalog/products/:productId
 * Update a product in Meta + DB
 */
router.put('/products/:productId', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { productId } = req.params;

        const product = await CatalogProduct.findOne({ tenantId, _id: productId });
        if (!product) return res.status(404).json({ error: 'Product not found' });

        const updates = req.body;
        const allowedFields = ['name', 'description', 'price', 'currency', 'imageUrl', 'availability', 'condition', 'link', 'brand', 'category', 'salePrice'];

        allowedFields.forEach(field => {
            if (updates[field] !== undefined) {
                product[field] = updates[field];
            }
        });

        // Push update to Meta
        if (product.productId) {
            try {
                const metaUpdateData = {
                    name: product.name,
                    description: product.description,
                    price: Math.round(product.price * 100),
                    currency: product.currency,
                    image_url: product.imageUrl,
                    availability: product.availability,
                    condition: product.condition,
                    ...(product.link && { url: product.link }),
                };
                await metaPost(product.productId, config.accessToken, metaUpdateData);
                product.isSynced = true;
                product.metaSyncedAt = new Date();
            } catch (metaErr) {
                console.warn('[PRODUCT UPDATE] Meta push failed:', metaErr.response?.data || metaErr.message);
                product.isSynced = false;
            }
        }

        await product.save();
        return res.json({ success: true, product });
    } catch (err) {
        console.error('[PRODUCT UPDATE]', err.response?.data || err.message);
        return res.status(500).json({ error: err.message });
    }
});

/**
 * DELETE /api/catalog/products/:productId
 * Delete a product from Meta + DB
 */
router.delete('/products/:productId', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { productId } = req.params;

        const product = await CatalogProduct.findOne({ tenantId, _id: productId });
        if (!product) return res.status(404).json({ error: 'Product not found' });

        // Delete from Meta
        if (product.productId) {
            try {
                await metaDelete(product.productId, config.accessToken);
            } catch (metaErr) {
                console.warn('[PRODUCT DELETE] Meta error:', metaErr.response?.data || metaErr.message);
            }
        }

        const catalogId = product.catalogId;
        await product.deleteOne();

        // Update product count
        await Catalog.findOneAndUpdate(
            { tenantId, catalogId },
            { $inc: { productCount: -1 } }
        );

        return res.json({ success: true });
    } catch (err) {
        console.error('[PRODUCT DELETE]', err.message);
        return res.status(500).json({ error: err.message });
    }
});

/**
 * POST /api/catalog/:catalogId/products/batch
 * Batch import products via Meta items_batch API
 * Body: { products: [ { retailerId, name, price, currency, imageUrl, ... } ] }
 */
router.post('/:catalogId/products/batch', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const tenantId = req.user.tenantId;
        const { catalogId } = req.params;
        const { products } = req.body;

        if (!products || !Array.isArray(products) || products.length === 0) {
            return res.status(400).json({ error: 'products array is required' });
        }

        // Build Meta batch payload
        const requests = products.map(p => ({
            method: 'CREATE',
            retailer_id: p.retailerId,
            data: {
                name: p.name,
                description: p.description || '',
                price: Math.round(parseFloat(p.price) * 100),
                currency: p.currency || 'INR',
                image_url: p.imageUrl,
                availability: p.availability || 'in stock',
                condition: p.condition || 'new',
                ...(p.link && { url: p.link }),
            }
        }));

        let metaBatchResult = null;
        try {
            metaBatchResult = await metaPost(
                `${catalogId}/items_batch`,
                config.accessToken,
                { allow_upsert: true, requests }
            );
        } catch (metaErr) {
            console.warn('[BATCH IMPORT] Meta error:', metaErr.response?.data || metaErr.message);
        }

        // Save all to DB
        const insertions = [];
        for (const p of products) {
            try {
                const doc = await CatalogProduct.findOneAndUpdate(
                    { tenantId, catalogId, retailerId: p.retailerId },
                    {
                        $set: {
                            name: p.name,
                            description: p.description || '',
                            price: parseFloat(p.price),
                            currency: p.currency || 'INR',
                            imageUrl: p.imageUrl,
                            availability: p.availability || 'in stock',
                            condition: p.condition || 'new',
                            link: p.link || '',
                            brand: p.brand || '',
                            category: p.category || '',
                            isSynced: !!metaBatchResult,
                            metaSyncedAt: metaBatchResult ? new Date() : null,
                        }
                    },
                    { upsert: true, new: true }
                );
                insertions.push(doc);
            } catch (dbErr) {
                console.warn('[BATCH IMPORT] DB error for', p.retailerId, dbErr.message);
            }
        }

        // Update product count
        const count = await CatalogProduct.countDocuments({ tenantId, catalogId });
        await Catalog.findOneAndUpdate({ tenantId, catalogId }, { $set: { productCount: count } });

        return res.json({ success: true, inserted: insertions.length, metaResult: metaBatchResult });
    } catch (err) {
        console.error('[BATCH IMPORT]', err.message);
        return res.status(500).json({ error: err.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
//  IMAGE UPLOAD ENDPOINT
// ─────────────────────────────────────────────────────────────────────────────

/**
 * POST /api/catalog/upload-image
 * Upload a product image to S3 and return the public URL
 */
router.post('/upload-image', authenticate, (req, res) => {
    uploadProductImage(req, res, (err) => {
        if (err) {
            console.error('[S3 UPLOAD]', err.message);
            return res.status(400).json({ error: err.message });
        }
        if (!req.file) {
            return res.status(400).json({ error: 'No image file received' });
        }
        const imageUrl = req.file.location; // S3 public URL
        return res.json({ success: true, imageUrl });
    });
});

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER ENDPOINTS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /api/catalog/orders
 * Fetch all orders for this tenant with optional status filter
 */
router.get('/orders', authenticate, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const { status, page = 1, limit = 30, catalogId } = req.query;

        const filter = { tenantId };
        if (status) filter.status = status;
        if (catalogId) filter.catalogId = catalogId;

        const skip = (parseInt(page) - 1) * parseInt(limit);

        const [orders, total, newCount] = await Promise.all([
            CatalogOrder.find(filter)
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(parseInt(limit))
                .lean(),
            CatalogOrder.countDocuments(filter),
            CatalogOrder.countDocuments({ tenantId, status: 'new' }),
        ]);

        return res.json({ success: true, orders, total, newCount, page: parseInt(page), limit: parseInt(limit) });
    } catch (err) {
        console.error('[ORDERS GET]', err.message);
        return res.status(500).json({ error: err.message });
    }
});

/**
 * PATCH /api/catalog/orders/:orderId
 * Update order status
 * Body: { status }
 */
router.patch('/orders/:orderId', authenticate, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const { orderId } = req.params;
        const { status } = req.body;

        const validStatuses = ['new', 'viewed', 'fulfilled', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ error: `Invalid status. Must be one of: ${validStatuses.join(', ')}` });
        }

        const order = await CatalogOrder.findOneAndUpdate(
            { tenantId, _id: orderId },
            { $set: { status } },
            { new: true }
        );

        if (!order) return res.status(404).json({ error: 'Order not found' });

        return res.json({ success: true, order });
    } catch (err) {
        console.error('[ORDER UPDATE]', err.message);
        return res.status(500).json({ error: err.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
//  MESSAGING ENDPOINTS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * POST /api/catalog/send-catalog-message
 * Send entire catalog message to a recipient
 * Body: { to, bodyText, thumbnailProductRetailerId }
 */
router.post('/send-catalog-message', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const { to, bodyText = 'Check out our catalog!', thumbnailProductRetailerId } = req.body;

        if (!to) return res.status(400).json({ error: 'Recipient phone number (to) is required' });
        if (!thumbnailProductRetailerId) return res.status(400).json({ error: 'thumbnailProductRetailerId is required' });

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to,
            type: 'interactive',
            interactive: {
                type: 'catalog_message',
                body: { text: bodyText },
                action: {
                    name: 'catalog_message',
                    parameters: {
                        thumbnail_product_retailer_id: thumbnailProductRetailerId,
                    },
                },
            },
        };

        const result = await metaPost(`${config.phoneNumberId}/messages`, config.accessToken, payload);
        return res.json({ success: true, messageId: result.messages?.[0]?.id });
    } catch (err) {
        console.error('[SEND CATALOG MSG]', err.response?.data || err.message);
        return res.status(500).json({ error: err.response?.data?.error?.message || err.message });
    }
});

/**
 * POST /api/catalog/send-product-message
 * Send a single product message
 * Body: { to, catalogId, productRetailerId, bodyText? }
 */
router.post('/send-product-message', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const { to, catalogId, productRetailerId, bodyText = '' } = req.body;

        if (!to || !catalogId || !productRetailerId) {
            return res.status(400).json({ error: 'to, catalogId, and productRetailerId are required' });
        }

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to,
            type: 'interactive',
            interactive: {
                type: 'product',
                ...(bodyText && { body: { text: bodyText } }),
                action: {
                    catalog_id: catalogId,
                    product_retailer_id: productRetailerId,
                },
            },
        };

        const result = await metaPost(`${config.phoneNumberId}/messages`, config.accessToken, payload);
        return res.json({ success: true, messageId: result.messages?.[0]?.id });
    } catch (err) {
        console.error('[SEND PRODUCT MSG]', err.response?.data || err.message);
        return res.status(500).json({ error: err.response?.data?.error?.message || err.message });
    }
});

/**
 * POST /api/catalog/send-multiproduct-message
 * Send a multi-product message (up to 30 products in sections)
 * Body: { to, catalogId, headerText, bodyText, sections: [{ title, products: [retailerId] }] }
 */
router.post('/send-multiproduct-message', authenticate, async (req, res) => {
    try {
        const config = await getTenantConfig(req);
        const { to, catalogId, headerText = 'Our Products', bodyText = 'Select items to add to your cart', footerText = '', sections } = req.body;

        if (!to || !catalogId || !sections?.length) {
            return res.status(400).json({ error: 'to, catalogId, and sections are required' });
        }

        const formattedSections = sections.map(s => ({
            title: s.title,
            product_items: s.products.map(retailerId => ({ product_retailer_id: retailerId })),
        }));

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to,
            type: 'interactive',
            interactive: {
                type: 'product_list',
                header: { type: 'text', text: headerText },
                body: { text: bodyText },
                ...(footerText && { footer: { text: footerText } }),
                action: {
                    catalog_id: catalogId,
                    sections: formattedSections,
                },
            },
        };

        const result = await metaPost(`${config.phoneNumberId}/messages`, config.accessToken, payload);
        return res.json({ success: true, messageId: result.messages?.[0]?.id });
    } catch (err) {
        console.error('[SEND MULTI PRODUCT MSG]', err.response?.data || err.message);
        return res.status(500).json({ error: err.response?.data?.error?.message || err.message });
    }
});

module.exports = router;
