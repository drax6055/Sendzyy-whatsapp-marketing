const axios = require('axios');

const GRAPH_API_VERSION = process.env.META_GRAPH_API_VERSION || 'v22.0';
const GRAPH_BASE_URL = `https://graph.facebook.com/${GRAPH_API_VERSION}`;

/**
 * Service for managing Meta WhatsApp Commerce Catalogs, Products, and Interactive Commerce Messages
 */
const CatalogService = {
    /**
     * Helper to validate WhatsApp configuration
     */
    ensureConfig(tenant) {
        const config = tenant?.whatsappConfig;
        if (!config || !config.accessToken || !config.phoneNumberId) {
            throw new Error('WhatsApp is not fully configured for this business. Please complete Meta onboarding first.');
        }
        return {
            accessToken: config.accessToken,
            phoneNumberId: config.phoneNumberId,
            wabaId: config.businessAccountId,
            portfolioId: config.businessPortfolioId || config.businessId,
            activeCatalogId: config.catalogId,
            catalogs: config.catalogs || [],
        };
    },

    /**
     * Auto-discovers and syncs all catalogs connected to the WABA or Business Portfolio
     */
    async syncCatalogs(tenant) {
        const { accessToken, wabaId, portfolioId } = this.ensureConfig(tenant);
        if (!wabaId) {
            throw new Error('WABA ID is missing on tenant configuration.');
        }

        let rawCatalogs = [];

        // 1. Query catalogs linked directly to WABA
        try {
            const wabaRes = await axios.get(`${GRAPH_BASE_URL}/${wabaId}/product_catalogs`, {
                params: {
                    fields: 'id,name,vertical,product_count',
                    access_token: accessToken,
                },
                timeout: 15000,
            });
            if (Array.isArray(wabaRes.data?.data)) {
                rawCatalogs.push(...wabaRes.data.data);
            }
        } catch (err) {
            console.warn('[CatalogService] WABA /product_catalogs query warning:', err.response?.data || err.message);
        }

        // 2. Query owned catalogs from Business Portfolio if available
        if (portfolioId) {
            try {
                const portRes = await axios.get(`${GRAPH_BASE_URL}/${portfolioId}/owned_product_catalogs`, {
                    params: {
                        fields: 'id,name,vertical,product_count',
                        access_token: accessToken,
                    },
                    timeout: 15000,
                });
                if (Array.isArray(portRes.data?.data)) {
                    rawCatalogs.push(...portRes.data.data);
                }
            } catch (portErr) {
                console.warn('[CatalogService] Portfolio /owned_product_catalogs query warning:', portErr.response?.data || portErr.message);
            }

            // 3. Query client/partner catalogs shared with Business Portfolio
            try {
                const clientRes = await axios.get(`${GRAPH_BASE_URL}/${portfolioId}/client_product_catalogs`, {
                    params: {
                        fields: 'id,name,vertical,product_count',
                        access_token: accessToken,
                    },
                    timeout: 15000,
                });
                if (Array.isArray(clientRes.data?.data)) {
                    rawCatalogs.push(...clientRes.data.data);
                }
            } catch (clientErr) {
                // Client catalogs may be empty or not granted, safe to ignore
            }
        }

        // Deduplicate catalogs by ID
        const catalogMap = new Map();
        for (const cat of rawCatalogs) {
            if (cat && cat.id && !catalogMap.has(cat.id)) {
                catalogMap.set(cat.id, {
                    catalogId: String(cat.id),
                    name: cat.name || `Catalog ${cat.id}`,
                    vertical: cat.vertical || 'commerce',
                    productCount: cat.product_count || 0,
                    discoveredAt: new Date(),
                });
            }
        }

        const currentActiveId = tenant.whatsappConfig.catalogId;
        const currentCatalogs = Array.isArray(tenant.whatsappConfig.catalogs) ? tenant.whatsappConfig.catalogs : [];
        const distinctCatalogs = Array.from(catalogMap.values());

        // If Meta returned 0 catalogs (due to transient network error, rate limit, or permissions),
        // NEVER disconnect an existing catalog! Preserve previous catalog configuration.
        if (distinctCatalogs.length === 0 && (currentActiveId || currentCatalogs.length > 0)) {
            console.log('[CatalogService] Preserving existing catalog configuration to prevent disconnection.');
            return {
                success: true,
                catalogId: currentActiveId,
                catalogs: currentCatalogs,
                count: currentCatalogs.length,
            };
        }

        // If a catalog was already active but not returned in the raw query (e.g. linked via partner),
        // preserve it in the catalog list so it doesn't get unlinked
        if (currentActiveId && !distinctCatalogs.some(c => c.catalogId === currentActiveId)) {
            const existingEntry = currentCatalogs.find(c => c.catalogId === currentActiveId);
            distinctCatalogs.unshift(existingEntry || {
                catalogId: currentActiveId,
                name: `Connected Catalog (${currentActiveId})`,
                vertical: 'commerce',
                productCount: 0,
                discoveredAt: new Date(),
            });
        }

        // Preserve current active catalog if valid, otherwise default to first
        let defaultActiveId = currentActiveId;
        if (!defaultActiveId || !distinctCatalogs.some(c => c.catalogId === defaultActiveId)) {
            defaultActiveId = distinctCatalogs[0]?.catalogId || currentActiveId || null;
        }

        const updatedCatalogs = distinctCatalogs.map(c => ({
            ...c,
            isDefault: c.catalogId === defaultActiveId,
        }));

        if (updatedCatalogs.length > 0 || defaultActiveId) {
            tenant.whatsappConfig.catalogs = updatedCatalogs;
            tenant.whatsappConfig.catalogId = defaultActiveId;
            await tenant.save();
        }

        return {
            success: true,
            catalogId: defaultActiveId,
            catalogs: updatedCatalogs,
            count: updatedCatalogs.length,
        };
    },

    /**
     * Switch default/active catalog for this tenant, or register and select a new one
     */
    async selectCatalog(tenant, catalogId, customName = null) {
        if (!catalogId) throw new Error('catalogId is required.');

        let catalogs = tenant.whatsappConfig?.catalogs || [];
        const existingIdx = catalogs.findIndex(c => c.catalogId === catalogId);

        let catName = customName;
        let vertical = 'commerce';
        let productCount = 0;

        // Try to fetch live catalog details from Meta if access token is available
        if (tenant.whatsappConfig?.accessToken) {
            try {
                const metaRes = await axios.get(`${GRAPH_BASE_URL}/${catalogId}`, {
                    params: {
                        fields: 'id,name,vertical,product_count',
                        access_token: tenant.whatsappConfig.accessToken,
                    },
                    timeout: 8000,
                });
                if (metaRes.data) {
                    catName = metaRes.data.name || catName;
                    vertical = metaRes.data.vertical || vertical;
                    productCount = metaRes.data.product_count ?? productCount;
                }
            } catch (metaErr) {
                // If Meta direct lookup fails, keep customName or default
            }
        }

        if (existingIdx >= 0) {
            catalogs[existingIdx] = {
                ...catalogs[existingIdx].toObject ? catalogs[existingIdx].toObject() : catalogs[existingIdx],
                name: catName || catalogs[existingIdx].name || `Catalog ${catalogId}`,
                vertical: vertical || catalogs[existingIdx].vertical || 'commerce',
                productCount: productCount || catalogs[existingIdx].productCount || 0,
            };
        } else {
            catalogs.push({
                catalogId,
                name: catName || `Catalog ${catalogId}`,
                vertical,
                isDefault: true,
                discoveredAt: new Date(),
                productCount,
            });
        }

        catalogs = catalogs.map(c => ({
            ...c.toObject ? c.toObject() : c,
            isDefault: c.catalogId === catalogId,
        }));

        tenant.whatsappConfig.catalogs = catalogs;
        tenant.whatsappConfig.catalogId = catalogId;
        await tenant.save();

        return {
            success: true,
            catalogId,
            activeCatalogId: catalogId,
            catalogs,
        };
    },

    /**
     * Remove / unlink a catalog from this tenant's catalog list
     */
    async removeCatalog(tenant, catalogId) {
        if (!catalogId) throw new Error('catalogId is required.');
        let catalogs = tenant.whatsappConfig?.catalogs || [];
        catalogs = catalogs.filter(c => c.catalogId !== catalogId);

        let activeCatalogId = tenant.whatsappConfig?.catalogId;
        if (activeCatalogId === catalogId) {
            activeCatalogId = catalogs.length > 0 ? catalogs[0].catalogId : null;
        }

        catalogs = catalogs.map(c => ({
            ...c.toObject ? c.toObject() : c,
            isDefault: c.catalogId === activeCatalogId,
        }));

        tenant.whatsappConfig.catalogs = catalogs;
        tenant.whatsappConfig.catalogId = activeCatalogId;
        await tenant.save();

        return {
            success: true,
            activeCatalogId,
            catalogs,
        };
    },

    /**
     * Fetch WhatsApp Commerce Settings (cart enabled & catalog visibility)
     */
    async getCommerceSettings(tenant) {
        const { accessToken, phoneNumberId } = this.ensureConfig(tenant);
        try {
            const res = await axios.get(`${GRAPH_BASE_URL}/${phoneNumberId}/whatsapp_commerce_settings`, {
                headers: { Authorization: `Bearer ${accessToken}` },
                timeout: 10000,
            });

            const data = res.data;
            let settingsObj = null;
            if (Array.isArray(data?.data) && data.data.length > 0) {
                settingsObj = data.data[0];
            } else if (data && typeof data === 'object') {
                settingsObj = data;
            }

            return {
                id: settingsObj?.id || phoneNumberId,
                is_cart_enabled: settingsObj?.is_cart_enabled ?? true,
                is_catalog_visible: settingsObj?.is_catalog_visible ?? true,
            };
        } catch (err) {
            console.warn('[CatalogService] getCommerceSettings failed, returning default:', err.response?.data || err.message);
            return {
                id: phoneNumberId,
                is_cart_enabled: true,
                is_catalog_visible: true,
            };
        }
    },

    /**
     * Update WhatsApp Commerce Settings (cart enabled & catalog visibility)
     */
    async updateCommerceSettings(tenant, { is_cart_enabled, is_catalog_visible }) {
        const { accessToken, phoneNumberId } = this.ensureConfig(tenant);

        const payload = {};
        if (typeof is_cart_enabled === 'boolean') payload.is_cart_enabled = is_cart_enabled;
        if (typeof is_catalog_visible === 'boolean') payload.is_catalog_visible = is_catalog_visible;

        const res = await axios.post(`${GRAPH_BASE_URL}/${phoneNumberId}/whatsapp_commerce_settings`, payload, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
            },
            timeout: 10000,
        });

        return {
            success: true,
            result: res.data,
            settings: {
                is_cart_enabled: payload.is_cart_enabled ?? true,
                is_catalog_visible: payload.is_catalog_visible ?? true,
            }
        };
    },

    /**
     * Fetch products from Meta Catalog Graph API
     */
    async getProducts(tenant, { catalogId, limit = 50, after, searchQuery } = {}) {
        const { accessToken, activeCatalogId } = this.ensureConfig(tenant);
        let targetCatalogId = catalogId || activeCatalogId;

        // Auto-discover if targetCatalogId is not set
        if (!targetCatalogId) {
            try {
                const syncRes = await this.syncCatalogs(tenant);
                targetCatalogId = syncRes.catalogId || (syncRes.catalogs && syncRes.catalogs[0]?.catalogId);
            } catch (autoErr) {
                console.warn('[CatalogService] Auto-sync in getProducts failed:', autoErr.message);
            }
        }

        if (!targetCatalogId) {
            return {
                data: [],
                products: [],
                catalogId: null,
                message: 'No Meta catalog connected yet. Sync catalogs first.',
            };
        }

        try {
            const params = {
                fields: 'id,retailer_id,name,description,price,sale_price,currency,image_url,availability,brand,visibility',
                limit: Math.min(Math.max(Number(limit) || 50, 1), 100),
                access_token: accessToken,
            };
            if (after) params.after = after;

            const res = await axios.get(`${GRAPH_BASE_URL}/${targetCatalogId}/products`, {
                params,
                timeout: 15000,
            });

            let items = res.data?.data || [];
            console.log('[CatalogService] Raw Meta products:', JSON.stringify(items, null, 2));

            // Format items into clean CatalogProduct model
            let products = items.map(p => {
                let parsedPrice = null;
                if (p.price != null) {
                    const raw = String(p.price).replace(/[^0-9.]/g, '');
                    const num = parseFloat(raw);
                    if (!isNaN(num)) {
                        parsedPrice = num;
                    }
                }

                let parsedSalePrice = null;
                if (p.sale_price != null) {
                    const rawSale = String(p.sale_price).replace(/[^0-9.]/g, '');
                    const numSale = parseFloat(rawSale);
                    if (!isNaN(numSale)) {
                        parsedSalePrice = numSale;
                    }
                }

                return {
                    retailer_id: p.retailer_id || p.id || '',
                    name: p.name || '',
                    description: p.description || '',
                    price: parsedPrice,
                    sale_price: parsedSalePrice,
                    currency: p.currency || 'INR',
                    image_url: p.image_url || '',
                    availability: p.availability === 'out of stock' ? 'out of stock' : 'in stock',
                    brand: p.brand || '',
                    visibility: p.visibility || 'published',
                };
            });

            if (searchQuery && typeof searchQuery === 'string' && searchQuery.trim().length > 0) {
                const q = searchQuery.toLowerCase().trim();
                products = products.filter(p =>
                    (p.name && p.name.toLowerCase().includes(q)) ||
                    (p.retailer_id && p.retailer_id.toLowerCase().includes(q)) ||
                    (p.description && p.description.toLowerCase().includes(q))
                );
            }

            return {
                data: products,
                products,
                paging: res.data?.paging || null,
                catalogId: targetCatalogId,
            };
        } catch (err) {
            console.error('[CatalogService] getProducts error:', err.response?.data || err.message);
            throw new Error(err.response?.data?.error?.message || 'Failed to fetch catalog products from Meta');
        }
    },

    /**
     * Add a product to the Meta Catalog via Graph API
     */
    async addProduct(tenant, productData = {}) {
        const { accessToken, activeCatalogId } = this.ensureConfig(tenant);
        const targetCatalogId = productData.catalogId || activeCatalogId;

        if (!targetCatalogId) {
            throw new Error('No active Meta catalog found to add this product to.');
        }

        const {
            retailer_id,
            retailerId,
            name,
            description,
            price,
            currency = 'INR',
            image_url,
            imageUrl,
            availability = 'in stock',
            brand,
            url,
        } = productData;

        const effectiveSku = retailer_id || retailerId;
        if (!effectiveSku || !name) {
            throw new Error('Product retailer_id (SKU) and name are required.');
        }

        const numericPrice = parseFloat(price) || 0;
        // Meta requires price in cents/minor units (e.g. 1000 for 10.00 INR/USD)
        const priceInCents = Math.round(numericPrice * 100);

        const metaPayload = {
            retailer_id: String(effectiveSku).trim(),
            name: String(name).trim(),
            description: description || name,
            price: priceInCents,
            currency: String(currency).toUpperCase().trim(),
            availability: availability === 'out of stock' ? 'out of stock' : 'in stock',
            condition: 'new',
        };

        const effectiveImage = image_url || imageUrl;
        if (effectiveImage) metaPayload.image_url = effectiveImage;
        if (brand) metaPayload.brand = brand;
        if (url) metaPayload.url = url;

        try {
            const res = await axios.post(`${GRAPH_BASE_URL}/${targetCatalogId}/products`, metaPayload, {
                params: { access_token: accessToken },
                headers: { 'Content-Type': 'application/json' },
                timeout: 15000,
            });

            return {
                success: true,
                id: res.data?.id,
                retailer_id: effectiveSku,
                name,
                description,
                price: numericPrice,
                currency,
                image_url: effectiveImage,
                availability,
                brand,
            };
        } catch (err) {
            console.error('[CatalogService] addProduct error:', err.response?.data || err.message);
            throw new Error(err.response?.data?.error?.message || 'Failed to create product in Meta Catalog');
        }
    },

    /**
     * Generic sender for interactive WhatsApp messages with full logging and socket broadcasts
     */
    async dispatchInteractiveMessage(dependencies, tenant, payload, { previewText, outboundMessageType = 'interactive', interactivePayload = {} }) {
        const { Message, Conversation, StatusMapping, broadcastMessages, broadcastConversations } = dependencies;
        const { accessToken, phoneNumberId } = this.ensureConfig(tenant);
        const tenantId = tenant._id.toString();
        const to = payload.to;

        // Post to Meta Graph API
        const metaRes = await axios.post(
            `${GRAPH_BASE_URL}/${phoneNumberId}/messages`,
            payload,
            {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                timeout: 15000,
            }
        );

        const wamid = metaRes.data?.messages?.[0]?.id || `wamid.${Date.now()}`;

        // 1. Create StatusMapping for status reconciliation
        if (StatusMapping) {
            try {
                await StatusMapping.findOneAndUpdate(
                    { wamid },
                    { wamid, tenantId, to, status: 'sent' },
                    { upsert: true }
                );
            } catch (smErr) {
                console.warn('[CatalogService] StatusMapping warning:', smErr.message);
            }
        }

        // 2. Update Conversation preview
        if (Conversation) {
            try {
                await Conversation.findOneAndUpdate(
                    { tenantId, contactId: to },
                    { lastMessage: previewText, lastActive: new Date(), $setOnInsert: { hasReply: false } },
                    { upsert: true }
                );
            } catch (cErr) {
                console.warn('[CatalogService] Conversation warning:', cErr.message);
            }
        }

        // 3. Persist Message to DB
        if (Message) {
            try {
                await Message.create({
                    tenantId,
                    contactId: to,
                    text: previewText,
                    isMe: true,
                    time: new Date().toISOString(),
                    messageType: outboundMessageType,
                    interactivePayload,
                    wamid,
                    status: 'sent',
                });
            } catch (mErr) {
                console.error('[CatalogService] Message save error:', mErr.message);
            }
        }

        // 4. Socket.IO broadcasts
        if (typeof broadcastConversations === 'function') {
            await broadcastConversations(tenantId);
        }
        if (typeof broadcastMessages === 'function') {
            await broadcastMessages(tenantId, to);
        }

        return {
            success: true,
            wamid,
            messages: [{ id: wamid }],
        };
    },

    /**
     * Helper to extract a normalized array of recipient phone numbers
     */
    extractRecipientList(reqBody) {
        const { to, recipients: rawRecipients } = reqBody;
        let list = [];
        if (Array.isArray(rawRecipients) && rawRecipients.length > 0) {
            list = rawRecipients;
        } else if (Array.isArray(to) && to.length > 0) {
            list = to;
        } else if (typeof rawRecipients === 'string' && rawRecipients.trim().length > 0) {
            list = rawRecipients.split(/[\n,]/);
        } else if (typeof to === 'string' && to.trim().length > 0) {
            list = to.split(/[\n,]/);
        }

        const normalized = list
            .map(n => String(n).replace(/[^0-9]/g, ''))
            .filter(n => n.length >= 10);

        // Deduplicate numbers
        return Array.from(new Set(normalized));
    },

    /**
     * Dispatch interactive messages to multiple recipients in controlled concurrency batches
     */
    async dispatchBulkInteractive(dependencies, tenant, recipients, buildPayloadFor, metaOptions) {
        const results = [];
        let successCount = 0;
        let failureCount = 0;

        // Process in concurrent batches of 5 to respect Meta rate limits
        const batchSize = 5;
        for (let i = 0; i < recipients.length; i += batchSize) {
            const chunk = recipients.slice(i, i + batchSize);
            const chunkPromises = chunk.map(async (recipient) => {
                try {
                    const payload = buildPayloadFor(recipient);
                    const res = await this.dispatchInteractiveMessage(dependencies, tenant, payload, metaOptions);
                    return { to: recipient, success: true, wamid: res.wamid };
                } catch (err) {
                    console.error(`[CatalogService] Bulk dispatch error for ${recipient}:`, err.response?.data || err.message);
                    return {
                        to: recipient,
                        success: false,
                        error: err.response?.data?.error?.message || err.message,
                    };
                }
            });

            const chunkResults = await Promise.all(chunkPromises);
            for (const r of chunkResults) {
                results.push(r);
                if (r.success) successCount++;
                else failureCount++;
            }
        }

        return {
            success: successCount > 0,
            total: recipients.length,
            successful: successCount,
            failed: failureCount,
            results,
            wamid: results.find(r => r.wamid)?.wamid || `bulk.${Date.now()}`,
            messages: results.filter(r => r.wamid).map(r => ({ id: r.wamid })),
        };
    },

    /**
     * Send Catalog Message (opens full catalog with thumbnail and "View Catalog" button)
     */
    async sendCatalogMessage(dependencies, tenant, reqBody) {
        const { bodyText, footerText, thumbnailProductRetailerId } = reqBody;
        const recipients = this.extractRecipientList(reqBody);

        if (recipients.length === 0 || !bodyText) {
            throw new Error('At least one valid recipient phone number and "bodyText" are required.');
        }

        const buildPayloadFor = (recipientPhone) => ({
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: recipientPhone,
            type: 'interactive',
            interactive: {
                type: 'catalog_message',
                body: { text: bodyText },
                ...(footerText ? { footer: { text: footerText } } : {}),
                action: {
                    name: 'catalog_message',
                    ...(thumbnailProductRetailerId ? {
                        parameters: {
                            thumbnail_product_retailer_id: thumbnailProductRetailerId,
                        }
                    } : {})
                }
            }
        });

        const previewText = `🛍️ Catalog Message: ${bodyText}`;
        const metaOptions = {
            previewText,
            outboundMessageType: 'interactive',
            interactivePayload: {
                type: 'catalog_message',
                bodyText,
                footerText,
                thumbnailProductRetailerId,
            }
        };

        if (recipients.length === 1) {
            return this.dispatchInteractiveMessage(dependencies, tenant, buildPayloadFor(recipients[0]), metaOptions);
        }

        return this.dispatchBulkInteractive(dependencies, tenant, recipients, buildPayloadFor, metaOptions);
    },

    /**
     * Send Single Product Message (highlights one SKU)
     */
    async sendSingleProduct(dependencies, tenant, reqBody) {
        const { catalogId, productRetailerId, bodyText, footerText } = reqBody;
        const effectiveCatalogId = catalogId || tenant.whatsappConfig?.catalogId;
        const recipients = this.extractRecipientList(reqBody);

        if (recipients.length === 0 || !effectiveCatalogId || !productRetailerId) {
            throw new Error('At least one valid recipient phone, "catalogId", and "productRetailerId" (SKU) are required.');
        }

        const buildPayloadFor = (recipientPhone) => ({
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: recipientPhone,
            type: 'interactive',
            interactive: {
                type: 'product',
                ...(bodyText ? { body: { text: bodyText } } : {}),
                ...(footerText ? { footer: { text: footerText } } : {}),
                action: {
                    catalog_id: effectiveCatalogId,
                    product_retailer_id: productRetailerId,
                }
            }
        });

        const previewText = `📦 Product: SKU ${productRetailerId}${bodyText ? ` — ${bodyText}` : ''}`;
        const metaOptions = {
            previewText,
            outboundMessageType: 'interactive',
            interactivePayload: {
                type: 'product',
                catalogId: effectiveCatalogId,
                productRetailerId,
                bodyText,
                footerText,
            }
        };

        if (recipients.length === 1) {
            return this.dispatchInteractiveMessage(dependencies, tenant, buildPayloadFor(recipients[0]), metaOptions);
        }

        return this.dispatchBulkInteractive(dependencies, tenant, recipients, buildPayloadFor, metaOptions);
    },

    /**
     * Send Multi-Product Message (up to 30 products across 10 sections)
     */
    async sendMultiProduct(dependencies, tenant, reqBody) {
        const { catalogId, headerText, bodyText, footerText, sections } = reqBody;
        const effectiveCatalogId = catalogId || tenant.whatsappConfig?.catalogId;
        const recipients = this.extractRecipientList(reqBody);

        if (recipients.length === 0 || !effectiveCatalogId || !headerText || !bodyText || !Array.isArray(sections) || sections.length === 0) {
            throw new Error('At least one valid recipient, "catalogId", "headerText", "bodyText", and at least one "sections" group are required.');
        }

        const formattedSections = sections.map(s => {
            const items = (s.productItems || s.product_items || s.productRetailerIds || []).map(item => {
                const sku = typeof item === 'string' ? item : (item.productRetailerId || item.product_retailer_id);
                return { product_retailer_id: sku };
            }).filter(i => !!i.product_retailer_id);

            return {
                title: (s.title || 'Products').substring(0, 24),
                product_items: items,
            };
        });

        const totalItems = formattedSections.reduce((sum, s) => sum + s.product_items.length, 0);
        if (totalItems === 0) {
            throw new Error('Sections must contain at least one valid product SKU.');
        }

        const buildPayloadFor = (recipientPhone) => ({
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: recipientPhone,
            type: 'interactive',
            interactive: {
                type: 'product_list',
                header: { type: 'text', text: headerText },
                body: { text: bodyText },
                ...(footerText ? { footer: { text: footerText } } : {}),
                action: {
                    catalog_id: effectiveCatalogId,
                    sections: formattedSections,
                }
            }
        });

        const previewText = `📑 Products (${totalItems} items): ${headerText}`;
        const metaOptions = {
            previewText,
            outboundMessageType: 'interactive',
            interactivePayload: {
                type: 'product_list',
                catalogId: effectiveCatalogId,
                headerText,
                bodyText,
                footerText,
                sections: formattedSections,
            }
        };

        if (recipients.length === 1) {
            return this.dispatchInteractiveMessage(dependencies, tenant, buildPayloadFor(recipients[0]), metaOptions);
        }

        return this.dispatchBulkInteractive(dependencies, tenant, recipients, buildPayloadFor, metaOptions);
    },

    /**
     * Send Product Carousel Message (2–10 scrollable product cards)
     */
    async sendCarousel(dependencies, tenant, reqBody) {
        const { bodyText, cards } = reqBody;
        const defaultCatalogId = tenant.whatsappConfig?.catalogId;
        const recipients = this.extractRecipientList(reqBody);

        if (recipients.length === 0 || !bodyText || !Array.isArray(cards) || cards.length < 2) {
            throw new Error('At least one valid recipient, "bodyText", and at least 2 product "cards" are required.');
        }

        const formattedCards = cards.map((c, idx) => {
            const cardCatalogId = c.catalogId || defaultCatalogId;
            const sku = c.productRetailerId || c.product_retailer_id;
            return {
                card_index: typeof c.cardIndex === 'number' ? c.cardIndex : idx,
                components: [
                    {
                        type: 'button',
                        sub_type: 'product',
                        parameters: [
                            {
                                type: 'product',
                                product: {
                                    catalog_id: cardCatalogId,
                                    product_retailer_id: sku,
                                }
                            }
                        ]
                    }
                ]
            };
        });

        const buildPayloadFor = (recipientPhone) => ({
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: recipientPhone,
            type: 'interactive',
            interactive: {
                type: 'carousel',
                body: { text: bodyText },
                action: {
                    cards: formattedCards,
                }
            }
        });

        const previewText = `🎠 Product Carousel (${formattedCards.length} cards): ${bodyText}`;
        const metaOptions = {
            previewText,
            outboundMessageType: 'interactive',
            interactivePayload: {
                type: 'carousel',
                bodyText,
                cards: formattedCards,
            }
        };

        if (recipients.length === 1) {
            return this.dispatchInteractiveMessage(dependencies, tenant, buildPayloadFor(recipients[0]), metaOptions);
        }

        return this.dispatchBulkInteractive(dependencies, tenant, recipients, buildPayloadFor, metaOptions);
    },

    /**
     * Resolves tenant's direct payment destination (UPI ID or Direct Bank Account via NPCI standard UPI VPA)
     */
    getTenantPaymentDestination(tenant) {
        if (!tenant) return null;

        const payoutCfg = tenant.payoutConfig || {};
        const upiConfig = tenant.upiPaymentConfig || {};

        const rawUpi = (payoutCfg.upiId && payoutCfg.upiId.trim()) || (upiConfig.upiId && upiConfig.upiId.trim()) || '';
        const rawAcc = payoutCfg.accountNumber ? String(payoutCfg.accountNumber).trim().replace(/\s+/g, '') : '';
        const rawIfsc = payoutCfg.ifscCode ? String(payoutCfg.ifscCode).trim().replace(/\s+/g, '').toUpperCase() : '';

        const merchantName = (payoutCfg.businessName && payoutCfg.businessName.trim())
            || (upiConfig.businessName && upiConfig.businessName.trim())
            || (payoutCfg.accountHolderName && payoutCfg.accountHolderName.trim())
            || tenant.name
            || 'Store';

        // 1. Explicit UPI ID (e.g. name@okaxis, shop@paytm)
        if (rawUpi && rawUpi.includes('@')) {
            return {
                type: 'upi',
                upiId: rawUpi,
                merchantName,
                businessName: payoutCfg.businessName || upiConfig.businessName || '',
                displayDetails: `UPI: ${rawUpi}`,
            };
        }

        // 2. Direct Bank Account via NPCI standard UPI VPA (e.g. x₹₹x₹₹@SBIN0000362.ifsc.npci)
        if (rawAcc && rawIfsc) {
            const npciVpa = `${rawAcc}@${rawIfsc}.ifsc.npci`;
            const bankName = payoutCfg.bankName || (rawIfsc.startsWith('SBIN') ? 'State Bank of India' : rawIfsc.slice(0, 4));
            const maskedAcc = rawAcc.length > 4 ? `•••• ${rawAcc.slice(-4)}` : rawAcc;
            return {
                type: 'bank',
                upiId: npciVpa,
                merchantName,
                accountHolderName: payoutCfg.accountHolderName || tenant.name,
                accountNumber: rawAcc,
                maskedAccountNumber: maskedAcc,
                ifscCode: rawIfsc,
                bankName,
                businessName: payoutCfg.businessName || '',
                displayDetails: `${bankName} A/C ${maskedAcc} (${rawIfsc})`,
            };
        }

        return null;
    },

    /**
     * Resolves the base URL for public checkout links
     */
    getServiceBaseUrl() {
        if (process.env.APP_URL && process.env.APP_URL.trim().length > 0) {
            return process.env.APP_URL.trim().replace(/\/$/, '');
        }
        const port = process.env.PORT || 3000;
        try {
            const os = require('os');
            const interfaces = os.networkInterfaces();
            for (const ifaceName of Object.keys(interfaces)) {
                for (const iface of interfaces[ifaceName]) {
                    if (iface.family === 'IPv4' && !iface.internal) {
                        return `http://${iface.address}:${port}`;
                    }
                }
            }
        } catch (_) {}
        return `http://localhost:${port}`;
    },

    /**
     * Creates a payment link for a WhatsApp catalog order and sends it to the customer via WhatsApp
     */
    async sendPaymentLinkForOrder(dependencies, tenant, order) {
        const { io, Message, Conversation, razorpay: globalRazorpay } = dependencies;
        const { accessToken, phoneNumberId } = this.ensureConfig(tenant);

        if (!order || !order.totalAmount || order.totalAmount <= 0) {
            throw new Error('Order total must be greater than 0 to generate a payment link.');
        }

        const orderCode = order._id.toString().slice(-6).toUpperCase();
        const currency = order.currency || 'INR';

        const cleanName = (order.contactName || 'Customer')
            .replace(/[^\w\s.-]/gi, '')
            .trim() || 'Customer';

        const cleanPhone = String(order.contactId || '').replace(/[^0-9]/g, '');
        const formattedContact = cleanPhone.startsWith('+') ? cleanPhone : `+${cleanPhone}`;

        // 1. Check if tenant has their OWN personal Razorpay API keys configured
        const customKeyId = tenant.whatsappConfig?.commerceSettings?.razorpayKeyId;
        const customKeySecret = tenant.whatsappConfig?.commerceSettings?.razorpayKeySecret;
        const usePersonalRazorpay = Boolean(customKeyId && customKeySecret && tenant.whatsappConfig?.commerceSettings?.paymentGateway === 'razorpay');

        const dest = this.getTenantPaymentDestination(tenant);
        const routeAccountId = tenant.payoutConfig?.razorpayAccountId;
        const masterKeyId = process.env.RAZORPAY_KEY_ID;
        const masterKeySecret = process.env.RAZORPAY_KEY_SECRET;
        const useRazorpayRoute = Boolean(!usePersonalRazorpay && routeAccountId && masterKeyId && masterKeySecret);

        let paymentUrl = '';
        let paymentLinkId = '';
        let displayText = '';
        let bodyText = '';
        let footerText = '';
        let paymentProvider = 'upi';

        if (usePersonalRazorpay) {
            // Tenant's personal Razorpay account
            paymentProvider = 'razorpay_upi';
            const RazorpayClass = require('razorpay');
            const razorpayInstance = new RazorpayClass({ key_id: customKeyId, key_secret: customKeySecret });
            const amountInPaise = Math.round(order.totalAmount * 100);
            const merchantName = (tenant.payoutConfig?.businessName && tenant.payoutConfig.businessName.trim()) || tenant.name || 'Store';

            const paymentLink = await razorpayInstance.paymentLink.create({
                amount: amountInPaise,
                currency,
                accept_partial: false,
                description: `Order #${orderCode} - ${merchantName}`,
                customer: {
                    name: cleanName,
                    contact: formattedContact,
                },
                notify: {
                    sms: false,
                    email: false,
                },
                reminder_enable: false,
                notes: {
                    orderId: order._id.toString(),
                    tenantId: order.tenantId ? order.tenantId.toString() : '',
                    contactId: String(order.contactId || ''),
                },
                callback_url: `${this.getServiceBaseUrl()}/catalog/order-success?orderId=${order._id}`,
                callback_method: 'get',
            });

            paymentUrl = paymentLink.short_url;
            paymentLinkId = paymentLink.id;
            displayText = `Pay ${currency} ${order.totalAmount.toFixed(2)}`;
            footerText = 'Auto-Verified UPI & Cards';
            bodyText = `🛍️ *Order Placed!* (Order #${orderCode})\n\n` +
                `• Items: ${order.items?.length || 0} item(s)\n` +
                `• Total Amount: *${currency} ${order.totalAmount.toFixed(2)}*\n` +
                `• Pay To: *${merchantName}*\n\n` +
                `Tap the button below to pay securely via Google Pay, PhonePe, Paytm, or UPI:\n(Payment is automatically verified instantly)`;

            order.paymentLinkId = paymentLinkId;
            order.paymentLinkUrl = paymentUrl;
            order.paymentProvider = 'razorpay_upi';
            order.paymentStatus = 'pending';
            await order.save();
        } else if (useRazorpayRoute) {
            // Platform Razorpay Route (Master gateway with automatic Route transfer to tenant's linked account)
            paymentProvider = 'razorpay_route';
            const RazorpayClass = require('razorpay');
            const razorpayInstance = new RazorpayClass({ key_id: masterKeyId, key_secret: masterKeySecret });
            const amountInPaise = Math.round(order.totalAmount * 100);
            const merchantName = (tenant.payoutConfig?.businessName && tenant.payoutConfig.businessName.trim()) || tenant.name || 'Store';

            const paymentLink = await razorpayInstance.paymentLink.create({
                amount: amountInPaise,
                currency,
                accept_partial: false,
                description: `Order #${orderCode} - ${merchantName}`,
                customer: {
                    name: cleanName,
                    contact: formattedContact,
                },
                notify: {
                    sms: false,
                    email: false,
                },
                reminder_enable: false,
                notes: {
                    orderId: order._id.toString(),
                    tenantId: order.tenantId ? order.tenantId.toString() : '',
                    contactId: String(order.contactId || ''),
                    routeAccountId: routeAccountId,
                    merchantName: merchantName,
                },
                callback_url: `${this.getServiceBaseUrl()}/catalog/order-success?orderId=${order._id}`,
                callback_method: 'get',
            });

            paymentUrl = paymentLink.short_url;
            paymentLinkId = paymentLink.id;
            displayText = `Pay ${currency} ${order.totalAmount.toFixed(2)}`;
            footerText = 'Auto-Verified UPI & Cards (Route)';
            bodyText = `🛍️ *Order Placed!* (Order #${orderCode})\n\n` +
                `• Items: ${order.items?.length || 0} item(s)\n` +
                `• Total Amount: *${currency} ${order.totalAmount.toFixed(2)}*\n` +
                `• Pay To: *${merchantName}*\n\n` +
                `Tap the button below to pay securely via Google Pay, PhonePe, Paytm, or UPI:\n(Payment is automatically verified instantly)`;

            order.paymentLinkId = paymentLinkId;
            order.paymentLinkUrl = paymentUrl;
            order.paymentProvider = 'razorpay_route';
            order.routeAccountId = routeAccountId;
            order.paymentStatus = 'pending';
            await order.save();
        } else if (process.env.CASHFREE_APP_ID && process.env.CASHFREE_SECRET_KEY) {
            // Platform Cashfree Payments Gateway (Instant UPI Intent, Cards, NetBanking with Easy Split routing)
            try {
                paymentProvider = 'cashfree';
                const merchantName = (tenant.payoutConfig?.businessName && tenant.payoutConfig.businessName.trim()) || tenant.name || 'Store';
                const cfOrderId = `order_${order._id}_${Date.now().toString().slice(-4)}`;
                const serviceBaseUrl = this.getServiceBaseUrl();
                const secureReturnUrl = serviceBaseUrl.startsWith('https://')
                    ? `${serviceBaseUrl}/catalog/order-success?orderId=${order._id}&order_id={order_id}`
                    : `https://sendzyy.com/catalog/order-success?orderId=${order._id}&order_id={order_id}`;

                const cfPayload = {
                    order_id: cfOrderId,
                    order_amount: Number(order.totalAmount.toFixed(2)),
                    order_currency: currency,
                    customer_details: {
                        customer_id: cleanPhone || String(order.contactId || 'cust_1'),
                        customer_phone: cleanPhone.length >= 10 ? cleanPhone.slice(-10) : '9876543210',
                        customer_name: cleanName,
                    },
                    order_meta: {
                        return_url: secureReturnUrl,
                        notify_url: `${serviceBaseUrl}/api/catalog/cashfree-webhook`,
                    }
                };

                // Attach Easy Split if vendor is active on Cashfree
                if (tenant.payoutConfig?.cashfreeVendorId) {
                    cfPayload.split = [
                        {
                            vendor_id: tenant.payoutConfig.cashfreeVendorId,
                            percentage: 100
                        }
                    ];
                }

                const cfRes = await axios.post('https://api.cashfree.com/pg/orders', cfPayload, {
                    headers: {
                        'x-client-id': process.env.CASHFREE_APP_ID,
                        'x-client-secret': process.env.CASHFREE_SECRET_KEY,
                        'x-api-version': '2023-08-01',
                        'Content-Type': 'application/json'
                    },
                    timeout: 10000
                });

                const cfData = cfRes.data;
                paymentUrl = `${serviceBaseUrl}/pay/cashfree/${order._id}`;
                paymentLinkId = cfData.cf_order_id || cfData.order_id;
                displayText = `Pay ${currency} ${order.totalAmount.toFixed(2)}`;
                footerText = 'Auto-Verified UPI & Cards (Cashfree)';
                bodyText = `🛍️ *Order Placed!* (Order #${orderCode})\n\n` +
                    `• Items: ${order.items?.length || 0} item(s)\n` +
                    `• Total Amount: *${currency} ${order.totalAmount.toFixed(2)}*\n` +
                    `• Pay To: *${merchantName}*\n\n` +
                    `Tap the button below to pay securely via Google Pay, PhonePe, Paytm, or Cards:\n(Payment is automatically verified instantly)`;

                order.paymentLinkId = paymentLinkId;
                order.paymentLinkUrl = paymentUrl;
                order.paymentProvider = 'cashfree';
                order.cashfreeOrderId = cfData.order_id;
                order.cashfreePaymentSessionId = cfData.payment_session_id;
                order.cashfreeVendorId = tenant.payoutConfig?.cashfreeVendorId || null;
                order.paymentStatus = 'pending';
                await order.save();
            } catch (cfErr) {
                console.warn('[CatalogService] Cashfree order create error, falling back to Direct UPI:', cfErr.response?.data || cfErr.message);
                if (dest) {
                    paymentProvider = 'upi';
                    const baseUrl = this.getServiceBaseUrl();
                    paymentUrl = `${baseUrl}/pay/upi/${order._id}`;
                    paymentLinkId = `upi_${order._id}`;
                    displayText = `Pay ${currency} ${order.totalAmount.toFixed(2)} via UPI`;
                    footerText = 'Direct UPI • Zero Fee Instant Settlement';
                    const destinationLine = dest.type === 'bank'
                        ? `• Bank Account: *${dest.displayDetails}*`
                        : `• UPI ID: \`${dest.upiId}\``;
                    bodyText = `🛍️ *Order Placed!* (Order #${orderCode})\n\n` +
                        `• Items: ${order.items?.length || 0} item(s)\n` +
                        `• Total Amount: *${currency} ${order.totalAmount.toFixed(2)}*\n` +
                        `• Pay To: *${dest.merchantName}*\n` +
                        `${destinationLine}\n\n` +
                        `Tap the button below to pay directly using Google Pay, PhonePe, Paytm, or any UPI app.`;
                    order.paymentLinkId = paymentLinkId;
                    order.paymentLinkUrl = paymentUrl;
                    order.paymentProvider = 'upi';
                    order.paymentStatus = 'pending';
                    await order.save();
                } else {
                    throw cfErr;
                }
            }
        } else if (dest) {
            // 2. Direct UPI / Direct Bank Settlement — Zero Middleman, 100% direct to tenant
            paymentProvider = 'upi';
            const baseUrl = this.getServiceBaseUrl();
            paymentUrl = `${baseUrl}/pay/upi/${order._id}`;
            paymentLinkId = `upi_${order._id}`;

            displayText = `Pay ${currency} ${order.totalAmount.toFixed(2)} via UPI`;
            footerText = 'Direct UPI • Zero Fee Instant Settlement';

            const destinationLine = dest.type === 'bank'
                ? `• Bank Account: *${dest.displayDetails}*`
                : `• UPI ID: \`${dest.upiId}\``;

            bodyText = `🛍️ *Order Placed!* (Order #${orderCode})\n\n` +
                `• Items: ${order.items?.length || 0} item(s)\n` +
                `• Total Amount: *${currency} ${order.totalAmount.toFixed(2)}*\n` +
                `• Pay To: *${dest.merchantName}*\n` +
                `${destinationLine}\n\n` +
                `Tap the button below to pay directly using Google Pay, PhonePe, Paytm, or any UPI app.\n` +
                `100% of your payment is deposited directly into the seller's account with zero delay.`;

            order.paymentLinkId = paymentLinkId;
            order.paymentLinkUrl = paymentUrl;
            order.paymentProvider = 'upi';
            order.paymentStatus = 'pending';
            await order.save();
        } else {
            throw new Error('Please configure Bank Settlement or UPI ID in Catalog Settings to accept payments.');
        }

        // 3. Send interactive WhatsApp message with CTA URL button
        const ctaPayload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: cleanPhone,
            type: 'interactive',
            interactive: {
                type: 'cta_url',
                header: {
                    type: 'text',
                    text: 'Payment Request 💳'
                },
                body: {
                    text: bodyText
                },
                footer: {
                    text: footerText
                },
                action: {
                    name: 'cta_url',
                    parameters: {
                        display_text: displayText,
                        url: paymentUrl
                    }
                }
            }
        };

        const previewText = `💳 Payment Link (${currency} ${order.totalAmount.toFixed(2)}): ${paymentUrl}`;

        let deliveryWarning = null;
        try {
            await this.dispatchInteractiveMessage(dependencies, tenant, ctaPayload, {
                previewText,
                outboundMessageType: 'interactive',
                interactivePayload: {
                    type: 'cta_url',
                    paymentLinkId: paymentLinkId,
                    paymentLinkUrl: paymentUrl,
                    orderId: order._id.toString(),
                    amount: order.totalAmount,
                    currency,
                    bodyText,
                }
            });
        } catch (metaErr) {
            console.warn('[CatalogService] cta_url interactive send failed, falling back to text with link:', metaErr.response?.data || metaErr.message);
            // Fallback to text message with link
            try {
                await axios.post(
                    `${GRAPH_BASE_URL}/${phoneNumberId}/messages`,
                    {
                        messaging_product: 'whatsapp',
                        to: cleanPhone,
                        type: 'text',
                        text: {
                            preview_url: true,
                            body: `${bodyText}\n\n👉 *Pay Now:* ${paymentUrl}`
                        }
                    },
                    { headers: { Authorization: `Bearer ${accessToken}` } }
                );

                if (Message) {
                    await Message.create({
                        tenantId: tenant._id.toString(),
                        contactId: order.contactId,
                        text: `${bodyText}\n\n👉 Pay Now: ${paymentUrl}`,
                        isMe: true,
                        time: new Date().toISOString(),
                        messageType: 'text',
                        status: 'sent',
                    }).catch(() => {});
                }
            } catch (fallbackErr) {
                console.warn('[CatalogService] WhatsApp message fallback also failed (e.g. 24h window closed):', fallbackErr.response?.data || fallbackErr.message);
                deliveryWarning = fallbackErr.response?.data?.error?.message || fallbackErr.message;
            }
        }

        if (io) {
            io.to(tenant._id.toString()).emit('catalog_order_payment_link_sent', {
                orderId: order._id.toString(),
                contactId: order.contactId,
                paymentLinkUrl: paymentUrl,
                totalAmount: order.totalAmount,
                currency,
                paymentProvider,
            });
        }

        return {
            success: true,
            paymentLinkId,
            paymentLinkUrl: paymentUrl,
            orderId: order._id.toString(),
            paymentProvider,
        };
    },

    /**
     * Marks order as paid, sends WhatsApp confirmation message to customer, and alerts dashboard
     */
    async handlePaymentSuccess(dependencies, { orderId, paymentId }) {
        const { io, Message, Conversation } = dependencies;
        const WhatsAppOrder = require('../models/WhatsAppOrder');

        const order = await WhatsAppOrder.findById(orderId);
        if (!order) {
            throw new Error(`Order ${orderId} not found`);
        }

        if (order.paymentStatus === 'paid') {
            return { success: true, message: 'Order was already marked as paid' };
        }

        order.paymentStatus = 'paid';
        order.status = 'accepted';
        order.paymentId = paymentId || order.paymentId || `pay_${Date.now()}`;
        order.paidAt = new Date();
        await order.save();

        let tenant = null;
        if (dependencies.Tenant) {
            tenant = await dependencies.Tenant.findById(order.tenantId);
        }

        // Razorpay Route: Automatically split and transfer payment to tenant linked account
        const targetAccountId = order.routeAccountId || tenant?.payoutConfig?.razorpayAccountId;
        const masterKeyId = process.env.RAZORPAY_KEY_ID;
        const masterKeySecret = process.env.RAZORPAY_KEY_SECRET;

        let resolvedPayId = paymentId || order.paymentId;
        if (targetAccountId && masterKeyId && masterKeySecret && resolvedPayId && !order.routeTransferId) {
            try {
                const RazorpayClass = require('razorpay');
                const masterRzp = new RazorpayClass({ key_id: masterKeyId, key_secret: masterKeySecret });

                // If payId is payment link id (plink_...), fetch actual payment id (pay_...)
                if (resolvedPayId.startsWith('plink_')) {
                    try {
                        const fetchedPlink = await masterRzp.paymentLink.fetch(resolvedPayId);
                        if (fetchedPlink?.payments?.[0]?.payment_id) {
                            resolvedPayId = fetchedPlink.payments[0].payment_id;
                            order.paymentId = resolvedPayId;
                        }
                    } catch (plinkFetchErr) {
                        console.warn('[CatalogService] Failed fetching payment link for payId:', plinkFetchErr.message);
                    }
                }

                if (resolvedPayId && resolvedPayId.startsWith('pay_')) {
                    const amountInPaise = Math.round(order.totalAmount * 100);
                    console.log(`[CatalogService] Splitting ₹${order.totalAmount} (${amountInPaise} paise) to Linked Account ${targetAccountId} for order ${order._id}...`);
                    const transferRes = await masterRzp.payments.transfer(resolvedPayId, {
                        transfers: [
                            {
                                account: targetAccountId,
                                amount: amountInPaise,
                                currency: order.currency || 'INR',
                                notes: {
                                    orderId: order._id.toString(),
                                    tenantId: order.tenantId ? order.tenantId.toString() : '',
                                },
                                on_hold: false,
                            }
                        ]
                    });
                    console.log('[CatalogService] Route transfer successful:', transferRes?.items?.[0]?.id || transferRes);
                    if (transferRes?.items?.[0]?.id) {
                        order.routeTransferId = transferRes.items[0].id;
                        await order.save();
                    }
                }
            } catch (routeErr) {
                console.error('[CatalogService] Razorpay Route transfer error:', routeErr.response?.data?.error?.description || routeErr.message);
            }
        }

        if (tenant && tenant.whatsappConfig?.accessToken && tenant.whatsappConfig?.phoneNumberId) {
            const { accessToken, phoneNumberId } = tenant.whatsappConfig;
            const orderCode = order._id.toString().slice(-6).toUpperCase();
            const currency = order.currency || 'INR';
            const confirmText = `🎉 *Payment Confirmed!*\n\n` +
                `We have received your payment of *${currency} ${order.totalAmount.toFixed(2)}* for Order *#${orderCode}*.\n\n` +
                `Your order is being processed and we will update you soon. Thank you for shopping with us!`;

            try {
                await axios.post(
                    `${GRAPH_BASE_URL}/${phoneNumberId}/messages`,
                    {
                        messaging_product: 'whatsapp',
                        to: String(order.contactId).replace(/[^0-9]/g, ''),
                        type: 'text',
                        text: { body: confirmText }
                    },
                    { headers: { Authorization: `Bearer ${accessToken}` } }
                );

                if (Message) {
                    await Message.create({
                        tenantId: order.tenantId,
                        contactId: order.contactId,
                        text: confirmText,
                        isMe: true,
                        time: new Date().toISOString(),
                        messageType: 'text',
                        status: 'sent',
                    }).catch(() => {});
                }
                if (Conversation) {
                    await Conversation.findOneAndUpdate(
                        { tenantId: order.tenantId, contactId: order.contactId },
                        { lastMessage: `✅ Payment Confirmed (${currency} ${order.totalAmount.toFixed(2)})`, lastActive: new Date() }
                    ).catch(() => {});
                }
            } catch (msgErr) {
                console.warn('[CatalogService] Payment confirmation WhatsApp message error:', msgErr.message);
            }
        }

        if (io) {
            io.to(order.tenantId.toString()).emit('catalog_order_paid', {
                orderId: order._id.toString(),
                contactId: order.contactId,
                totalAmount: order.totalAmount,
                currency: order.currency,
                paymentId: order.paymentId,
                status: order.status,
                paymentStatus: order.paymentStatus,
            });
        }

        return {
            success: true,
            orderId: order._id.toString(),
            status: order.status,
            paymentStatus: order.paymentStatus,
        };
    },

    /**
     * Handles payment failure / cancellation, updates order status, and alerts dashboard
     */
    async handlePaymentFailure(dependencies, { orderId, reason, paymentId }) {
        const { io, Message, Conversation } = dependencies;
        const WhatsAppOrder = require('../models/WhatsAppOrder');

        const order = await WhatsAppOrder.findById(orderId);
        if (!order) {
            return { success: false, error: 'Order not found' };
        }

        // If order was already paid by a prior or subsequent attempt, do not overwrite with failed
        if (order.paymentStatus === 'paid') {
            return { success: true, message: 'Order was already paid' };
        }

        order.paymentStatus = 'failed';
        await order.save();

        let tenant = null;
        if (dependencies.Tenant) {
            tenant = await dependencies.Tenant.findById(order.tenantId);
        }

        if (tenant && tenant.whatsappConfig?.accessToken && tenant.whatsappConfig?.phoneNumberId) {
            const { accessToken, phoneNumberId } = tenant.whatsappConfig;
            const orderCode = order._id.toString().slice(-6).toUpperCase();
            const currency = order.currency || 'INR';
            const cleanReason = reason ? ` (${reason})` : '';
            const retryText = `⚠️ *Payment Unsuccessful*\n\n` +
                `Your payment of *${currency} ${order.totalAmount.toFixed(2)}* for Order *#${orderCode}* could not be processed${cleanReason}.\n\n` +
                (order.paymentLinkUrl ? `👉 *Tap here to retry your payment:* ${order.paymentLinkUrl}\n\n` : '') +
                `_If any money was debited from your bank account, it will automatically be refunded by your bank within 24–48 hours._`;

            try {
                await axios.post(
                    `${GRAPH_BASE_URL}/${phoneNumberId}/messages`,
                    {
                        messaging_product: 'whatsapp',
                        to: String(order.contactId).replace(/[^0-9]/g, ''),
                        type: 'text',
                        text: { body: retryText }
                    },
                    { headers: { Authorization: `Bearer ${accessToken}` } }
                );

                if (Message) {
                    await Message.create({
                        tenantId: order.tenantId,
                        contactId: order.contactId,
                        text: retryText,
                        isMe: true,
                        time: new Date().toISOString(),
                        messageType: 'text',
                        status: 'sent',
                    }).catch(() => {});
                }
                if (Conversation) {
                    await Conversation.findOneAndUpdate(
                        { tenantId: order.tenantId, contactId: order.contactId },
                        { lastMessage: `⚠️ Payment Failed for Order #${orderCode}`, lastActive: new Date() }
                    ).catch(() => {});
                }
            } catch (msgErr) {
                console.warn('[CatalogService] Payment failure message error:', msgErr.message);
            }
        }

        if (io) {
            io.to(order.tenantId.toString()).emit('catalog_order_paid', {
                orderId: order._id.toString(),
                contactId: order.contactId,
                totalAmount: order.totalAmount,
                currency: order.currency,
                paymentId: paymentId || order.paymentId,
                status: order.status,
                paymentStatus: order.paymentStatus,
                failureReason: reason,
            });
        }

        return {
            success: true,
            orderId: order._id.toString(),
            status: order.status,
            paymentStatus: order.paymentStatus,
        };
    }
};

module.exports = CatalogService;
