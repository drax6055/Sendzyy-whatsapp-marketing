/**
 * test_catalog_fixes.js
 * Verification test suite for Catalog Create & Link bug fixes using supertest.
 */

const express = require('express');
const request = require('supertest');
const axios = require('axios');
const jwt = require('jsonwebtoken');
const fs = require('fs');

const JWT_SECRET = 'test_secret_key_123';
process.env.JWT_SECRET = JWT_SECRET;

// Require catalog routes (which imports Catalog model)
const Catalog = require('./models/Catalog');
const catalogRoutes = require('./routes/catalogRoutes');

// Mock in-memory database storage
const mockCatalogs = [];

Catalog.find = (filter) => ({
    lean: async () => mockCatalogs.filter(c => !filter.tenantId || c.tenantId === filter.tenantId),
});

Catalog.create = async (doc) => {
    const item = { ...doc, _id: 'mock_id_' + Date.now() };
    mockCatalogs.push(item);
    return item;
};

Catalog.findOneAndUpdate = async (filter, update, options) => {
    let item = mockCatalogs.find(c => c.tenantId === filter.tenantId && c.catalogId === filter.catalogId);
    if (!item && options?.upsert) {
        item = { tenantId: filter.tenantId, catalogId: filter.catalogId, ...update.$set, _id: 'mock_id_' + Date.now() };
        mockCatalogs.push(item);
    } else if (item && update.$set) {
        Object.assign(item, update.$set);
    }
    return item;
};

const MockTenant = {
    findById: (id) => ({
        lean: async () => ({
            _id: id,
            whatsappConfig: {
                accessToken: 'EAAG_mock_access_token_1234567890',
                phoneNumberId: '10987654321',
                businessAccountId: '8811451312966799', // WABA ID
                businessPortfolioId: '8811451312966799', // Mistakenly same as WABA
            },
        }),
    }),
};

async function runTests() {
    console.log('═══════════════════════════════════════════════════════════════');
    console.log('🧪 Starting Catalog API Unit & Integration Tests');
    console.log('═══════════════════════════════════════════════════════════════\n');

    let passedCount = 0;
    let failedCount = 0;

    function assert(name, condition, details = '') {
        if (condition) {
            console.log(`  ✅ PASS: ${name}`);
            passedCount++;
        } else {
            console.error(`  ❌ FAIL: ${name} ${details ? '- ' + details : ''}`);
            failedCount++;
        }
    }

    // ── TEST 1: Check token scope in server.js ───────────────────────────────
    console.log('Test Suite 1: Token Scope Verification');
    const serverJsContent = fs.readFileSync('./server.js', 'utf8');
    const hasCatalogScope = serverJsContent.includes("'whatsapp_business_management,whatsapp_business_messaging,catalog_management'");
    assert('server.js requests catalog_management in system user token scope', hasCatalogScope);

    // Setup Express App
    const app = express();
    app.use(express.json());
    app.set('TenantModel', MockTenant);
    app.use('/api/catalog', catalogRoutes);

    const testToken = jwt.sign({ tenantId: 'tenant_test_123', userId: 'user_1' }, JWT_SECRET);

    // ── TEST 2: POST /api/catalog/link Parameter & Content-Type ──────────────
    console.log('\nTest Suite 2: POST /api/catalog/link Testing');

    let capturedPostCalls = [];
    const originalPost = axios.post;
    const originalGet = axios.get;

    // Test 2a: Link with Meta API success
    axios.post = async (url, data, config) => {
        capturedPostCalls.push({ url, data, config });
        if (url.includes('/product_catalogs')) {
            return { status: 200, data: { success: true } };
        }
        return { status: 200, data: {} };
    };

    axios.get = async (url, config) => {
        if (url.includes('/1049858267742855')) {
            return { status: 200, data: { id: '1049858267742855', name: 'Meta Live Catalog' } };
        }
        return { status: 200, data: {} };
    };

    let linkRes = await request(app)
        .post('/api/catalog/link')
        .set('Authorization', `Bearer ${testToken}`)
        .send({ catalogId: '1049858267742855' });

    assert('POST /link returns 200 OK on Meta success', linkRes.status === 200, `Got status: ${linkRes.status}, body: ${JSON.stringify(linkRes.body)}`);
    assert('POST /link returns isLinked: true', linkRes.body?.isLinked === true);
    assert('POST /link resolved catalogName from Meta', linkRes.body?.catalogName === 'Meta Live Catalog');

    // Check captured post parameters
    const lastLinkCall = capturedPostCalls.find(c => c.url.includes('/product_catalogs'));
    assert('Meta link call used application/x-www-form-urlencoded', 
        lastLinkCall?.config?.headers?.['Content-Type'] === 'application/x-www-form-urlencoded');
    assert('Meta link call passed catalog_id in query params', 
        lastLinkCall?.config?.params?.catalog_id === '1049858267742855');
    assert('Meta link call passed catalog_id in URLSearchParams body', 
        lastLinkCall?.data?.toString().includes('catalog_id=1049858267742855'));

    // Test 2b: Link when Meta returns "already connected"
    capturedPostCalls = [];
    axios.post = async (url, data, config) => {
        const err = new Error('Catalog is already connected to this WABA');
        err.response = { status: 400, data: { error: { message: 'Catalog is already connected to this WABA', code: 2388044 } } };
        throw err;
    };

    let alreadyLinkedRes = await request(app)
        .post('/api/catalog/link')
        .set('Authorization', `Bearer ${testToken}`)
        .send({ catalogId: '999888777666', catalogName: 'Already Linked Catalog' });

    assert('POST /link returns 200 OK when already connected', alreadyLinkedRes.status === 200);
    assert('POST /link treats already connected catalog as isLinked: true', alreadyLinkedRes.body?.isLinked === true);

    // Test 2c: Link when Meta returns "Invalid parameter" / Error 100
    axios.post = async (url, data, config) => {
        const err = new Error('Invalid parameter');
        err.response = { status: 400, data: { error: { message: 'Invalid parameter', code: 100 } } };
        throw err;
    };

    let invalidParamRes = await request(app)
        .post('/api/catalog/link')
        .set('Authorization', `Bearer ${testToken}`)
        .send({ catalogId: '777666555444', catalogName: 'Local Fallback Catalog' });

    assert('POST /link does NOT return 500 error when Meta fails with Error 100', invalidParamRes.status === 200);
    assert('POST /link gracefully saves with isLinked: false', invalidParamRes.body?.isLinked === false);
    assert('POST /link includes warning message in response', invalidParamRes.body?.warning?.includes('Invalid parameter'));

    // ── TEST 3: POST /api/catalog/create Testing ─────────────────────────────
    console.log('\nTest Suite 3: POST /api/catalog/create Testing');

    // Test 3a: Create when Meta fails (due to Business ID or token permissions)
    axios.get = async (url, config) => {
        return {
            status: 200,
            data: {
                owner_business_info: { id: '999000111222' },
            },
        };
    };

    axios.post = async (url, data, config) => {
        if (url.includes('/owned_product_catalogs')) {
            const err = new Error('Unsupported post request. Object with ID does not exist');
            err.response = { status: 400, data: { error: { message: 'Unsupported post request. Object with ID does not exist', code: 100 } } };
            throw err;
        }
        return { status: 200, data: {} };
    };

    let createFailMetaRes = await request(app)
        .post('/api/catalog/create')
        .set('Authorization', `Bearer ${testToken}`)
        .send({ name: 'Spring Collection 2026', verticalType: 'commerce' });

    assert('POST /create does NOT return 500 when Meta creation fails', createFailMetaRes.status === 200);
    assert('POST /create generates Sendzyy local catalog ID (starts with cat_)', 
        createFailMetaRes.body?.catalog?.catalogId?.startsWith('cat_'));
    assert('POST /create returns catalog with name Spring Collection 2026', 
        createFailMetaRes.body?.catalog?.catalogName === 'Spring Collection 2026');

    // Test 3b: Create when Meta succeeds
    capturedPostCalls = [];
    axios.post = async (url, data, config) => {
        capturedPostCalls.push({ url, data, config });
        if (url.includes('/owned_product_catalogs')) {
            return { status: 200, data: { id: 'meta_new_cat_555' } };
        }
        if (url.includes('/product_catalogs')) {
            return { status: 200, data: { success: true } };
        }
        return { status: 200, data: {} };
    };

    let createSuccessRes = await request(app)
        .post('/api/catalog/create')
        .set('Authorization', `Bearer ${testToken}`)
        .send({ name: 'Summer Mega Sale', verticalType: 'commerce' });

    assert('POST /create returns 200 OK when Meta succeeds', createSuccessRes.status === 200);
    assert('POST /create returns Meta catalog ID', createSuccessRes.body?.catalog?.catalogId === 'meta_new_cat_555');
    assert('POST /create auto-links to WABA with isLinked: true', createSuccessRes.body?.catalog?.isLinked === true);

    // ── TEST 4: GET /api/catalog/list Testing ────────────────────────────────
    console.log('\nTest Suite 4: GET /api/catalog/list Testing');

    // Test 4a: Meta list returns catalogs
    axios.get = async (url, config) => {
        if (url.includes('/product_catalogs')) {
            return {
                status: 200,
                data: {
                    data: [
                        { id: '1049858267742855', name: 'Meta Live Catalog', vertical: 'commerce', product_count: 12 },
                    ],
                },
            };
        }
        return { status: 200, data: {} };
    };

    let listRes = await request(app)
        .get('/api/catalog/list')
        .set('Authorization', `Bearer ${testToken}`);

    assert('GET /list returns 200 OK', listRes.status === 200);
    assert('GET /list merges Meta and DB catalogs', listRes.body?.catalogs?.length > 0);

    // Test 4b: Meta list throws an error (e.g. temporary API failure)
    axios.get = async (url, config) => {
        const err = new Error('Meta API error');
        err.response = { status: 500, data: { error: { message: 'Meta internal error' } } };
        throw err;
    };

    let listFallbackRes = await request(app)
        .get('/api/catalog/list')
        .set('Authorization', `Bearer ${testToken}`);

    assert('GET /list does NOT return 500 when Meta throws error', listFallbackRes.status === 200);
    assert('GET /list returns DB catalogs on Meta error', Array.isArray(listFallbackRes.body?.catalogs));

    // Restore original axios
    axios.post = originalPost;
    axios.get = originalGet;

    console.log('\n═══════════════════════════════════════════════════════════════');
    console.log(`🏁 Test Results: ${passedCount} PASSED, ${failedCount} FAILED`);
    console.log('═══════════════════════════════════════════════════════════════\n');

    if (failedCount > 0) {
        process.exit(1);
    } else {
        process.exit(0);
    }
}

runTests().catch(err => {
    console.error('Fatal test error:', err);
    process.exit(1);
});
