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
            portfolioId: config.businessPortfolioId,
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
        const distinctCatalogs = Array.from(catalogMap.values());

        // Preserve current active catalog if still valid, otherwise default to first
        let defaultActiveId = currentActiveId;
        if (!defaultActiveId || !catalogMap.has(defaultActiveId)) {
            defaultActiveId = distinctCatalogs[0]?.catalogId || null;
        }

        const updatedCatalogs = distinctCatalogs.map(c => ({
            ...c,
            isDefault: c.catalogId === defaultActiveId,
        }));

        tenant.whatsappConfig.catalogs = updatedCatalogs;
        tenant.whatsappConfig.catalogId = defaultActiveId;
        await tenant.save();

        return {
            success: true,
            catalogId: defaultActiveId,
            catalogs: updatedCatalogs,
            count: updatedCatalogs.length,
        };
    },

    /**
     * Switch default/active catalog for this tenant
     */
    async selectCatalog(tenant, catalogId) {
        if (!catalogId) throw new Error('catalogId is required.');

        let catalogs = tenant.whatsappConfig?.catalogs || [];
        const exists = catalogs.some(c => c.catalogId === catalogId);

        if (!exists) {
            // If not found in cached list, add it
            catalogs.push({
                catalogId,
                name: `Catalog ${catalogId}`,
                vertical: 'commerce',
                isDefault: true,
                discoveredAt: new Date(),
                productCount: 0,
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
            activeCatalogId: catalogId,
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
        const targetCatalogId = catalogId || activeCatalogId;

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
                fields: 'id,retailer_id,name,description,price,currency,image_url,availability,brand,visibility',
                limit: Math.min(Math.max(Number(limit) || 50, 1), 100),
                access_token: accessToken,
            };
            if (after) params.after = after;

            const res = await axios.get(`${GRAPH_BASE_URL}/${targetCatalogId}/products`, {
                params,
                timeout: 15000,
            });

            let items = res.data?.data || [];

            // Format items into clean CatalogProduct model
            let products = items.map(p => {
                let parsedPrice = null;
                if (p.price != null) {
                    const raw = String(p.price).replace(/[^0-9.]/g, '');
                    const num = parseFloat(raw);
                    if (!isNaN(num)) {
                        // Meta Graph API returns price in cents / minor currency units if integer > 100
                        parsedPrice = (Number.isInteger(num) && num > 100) ? num / 100 : num;
                    }
                }

                return {
                    retailer_id: p.retailer_id || p.id || '',
                    name: p.name || '',
                    description: p.description || '',
                    price: parsedPrice,
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
     * Send Catalog Message (opens full catalog with thumbnail and "View Catalog" button)
     */
    async sendCatalogMessage(dependencies, tenant, reqBody) {
        const { to, bodyText, footerText, thumbnailProductRetailerId } = reqBody;
        if (!to || !bodyText) {
            throw new Error('Recipient "to" and "bodyText" are required.');
        }

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: String(to).replace(/[^0-9]/g, ''),
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
        };

        const previewText = `🛍️ Catalog Message: ${bodyText}`;
        return this.dispatchInteractiveMessage(dependencies, tenant, payload, {
            previewText,
            outboundMessageType: 'interactive',
            interactivePayload: {
                type: 'catalog_message',
                bodyText,
                footerText,
                thumbnailProductRetailerId,
            }
        });
    },

    /**
     * Send Single Product Message (highlights one SKU)
     */
    async sendSingleProduct(dependencies, tenant, reqBody) {
        const { to, catalogId, productRetailerId, bodyText, footerText } = reqBody;
        const effectiveCatalogId = catalogId || tenant.whatsappConfig?.catalogId;

        if (!to || !effectiveCatalogId || !productRetailerId) {
            throw new Error('Recipient "to", "catalogId", and "productRetailerId" (SKU) are required.');
        }

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: String(to).replace(/[^0-9]/g, ''),
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
        };

        const previewText = `📦 Product: SKU ${productRetailerId}${bodyText ? ` — ${bodyText}` : ''}`;
        return this.dispatchInteractiveMessage(dependencies, tenant, payload, {
            previewText,
            outboundMessageType: 'interactive',
            interactivePayload: {
                type: 'product',
                catalogId: effectiveCatalogId,
                productRetailerId,
                bodyText,
                footerText,
            }
        });
    },

    /**
     * Send Multi-Product Message (up to 30 products across 10 sections)
     */
    async sendMultiProduct(dependencies, tenant, reqBody) {
        const { to, catalogId, headerText, bodyText, footerText, sections } = reqBody;
        const effectiveCatalogId = catalogId || tenant.whatsappConfig?.catalogId;

        if (!to || !effectiveCatalogId || !headerText || !bodyText || !Array.isArray(sections) || sections.length === 0) {
            throw new Error('Recipient "to", "catalogId", "headerText", "bodyText", and at least one "sections" group are required.');
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

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: String(to).replace(/[^0-9]/g, ''),
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
        };

        const previewText = `📑 Products (${totalItems} items): ${headerText}`;
        return this.dispatchInteractiveMessage(dependencies, tenant, payload, {
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
        });
    },

    /**
     * Send Product Carousel Message (2–10 scrollable product cards)
     */
    async sendCarousel(dependencies, tenant, reqBody) {
        const { to, bodyText, cards } = reqBody;
        const defaultCatalogId = tenant.whatsappConfig?.catalogId;

        if (!to || !bodyText || !Array.isArray(cards) || cards.length < 2) {
            throw new Error('Recipient "to", "bodyText", and at least 2 product "cards" are required.');
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

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: String(to).replace(/[^0-9]/g, ''),
            type: 'interactive',
            interactive: {
                type: 'carousel',
                body: { text: bodyText },
                action: {
                    cards: formattedCards,
                }
            }
        };

        const previewText = `🎠 Product Carousel (${formattedCards.length} cards): ${bodyText}`;
        return this.dispatchInteractiveMessage(dependencies, tenant, payload, {
            previewText,
            outboundMessageType: 'interactive',
            interactivePayload: {
                type: 'carousel',
                bodyText,
                cards: formattedCards,
            }
        });
    },

    /**
     * Creates a Razorpay Payment Link for a WhatsApp catalog order and sends it to the customer via WhatsApp
     */
    async sendPaymentLinkForOrder(dependencies, tenant, order) {
        const { io, Message, Conversation, razorpay: globalRazorpay } = dependencies;
        const { accessToken, phoneNumberId } = this.ensureConfig(tenant);

        if (!order || !order.totalAmount || order.totalAmount <= 0) {
            throw new Error('Order total must be greater than 0 to generate a payment link.');
        }

        const RazorpayClass = require('razorpay');
        const customKeyId = tenant.whatsappConfig?.commerceSettings?.razorpayKeyId;
        const customKeySecret = tenant.whatsappConfig?.commerceSettings?.razorpayKeySecret;

        let razorpayInstance = null;
        if (customKeyId && customKeySecret) {
            razorpayInstance = new RazorpayClass({ key_id: customKeyId, key_secret: customKeySecret });
        } else if (globalRazorpay) {
            razorpayInstance = globalRazorpay;
        } else if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
            razorpayInstance = new RazorpayClass({ key_id: process.env.RAZORPAY_KEY_ID, key_secret: process.env.RAZORPAY_KEY_SECRET });
        }

        if (!razorpayInstance) {
            throw new Error('Razorpay payment gateway is not configured on this account.');
        }

        const orderCode = order._id.toString().slice(-6).toUpperCase();
        const amountInPaise = Math.round(order.totalAmount * 100);
        const currency = order.currency || 'INR';

        // 1. Generate Razorpay Payment Link
        const paymentLink = await razorpayInstance.paymentLink.create({
            amount: amountInPaise,
            currency,
            accept_partial: false,
            description: `Payment for Order #${orderCode}`,
            customer: {
                name: order.contactName || 'Valued Customer',
                contact: order.contactId.startsWith('+') ? order.contactId : `+${order.contactId}`,
            },
            notify: {
                sms: false,
                email: false,
            },
            reminder_enable: false,
            notes: {
                orderId: order._id.toString(),
                tenantId: order.tenantId.toString(),
                contactId: order.contactId,
            },
            callback_url: `${process.env.APP_URL || 'https://sendzyy.com'}/catalog/order-success?orderId=${order._id}`,
            callback_method: 'get',
        });

        // 2. Update order record with payment link details
        order.paymentLinkId = paymentLink.id;
        order.paymentLinkUrl = paymentLink.short_url;
        order.paymentStatus = 'pending';
        await order.save();

        // 3. Send interactive WhatsApp message with CTA URL button
        const bodyText = `🛍️ *Order Placed!* (Order #${orderCode})\n\n` +
            `• Items: ${order.items?.length || 0} item(s)\n` +
            `• Total Amount: ${currency} ${order.totalAmount.toFixed(2)}\n\n` +
            `Please complete your payment securely via UPI (GPay/PhonePe/Paytm), Card, or NetBanking:`;

        const ctaPayload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: String(order.contactId).replace(/[^0-9]/g, ''),
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
                    text: 'Powered by Sendzyy & Razorpay'
                },
                action: {
                    name: 'cta_url',
                    parameters: {
                        display_text: `Pay ${currency} ${order.totalAmount.toFixed(2)}`,
                        url: paymentLink.short_url
                    }
                }
            }
        };

        const previewText = `💳 Payment Link (${currency} ${order.totalAmount.toFixed(2)}): ${paymentLink.short_url}`;

        try {
            await this.dispatchInteractiveMessage(dependencies, tenant, ctaPayload, {
                previewText,
                outboundMessageType: 'interactive',
                interactivePayload: {
                    type: 'cta_url',
                    paymentLinkId: paymentLink.id,
                    paymentLinkUrl: paymentLink.short_url,
                    orderId: order._id.toString(),
                    amount: order.totalAmount,
                    currency,
                    bodyText,
                }
            });
        } catch (metaErr) {
            console.warn('[CatalogService] cta_url interactive send failed, falling back to text with link:', metaErr.message);
            // Fallback to text message with link
            await axios.post(
                `${GRAPH_BASE_URL}/${phoneNumberId}/messages`,
                {
                    messaging_product: 'whatsapp',
                    to: String(order.contactId).replace(/[^0-9]/g, ''),
                    type: 'text',
                    text: {
                        preview_url: true,
                        body: `${bodyText}\n\n👉 *Pay Now:* ${paymentLink.short_url}`
                    }
                },
                { headers: { Authorization: `Bearer ${accessToken}` } }
            );

            if (Message) {
                await Message.create({
                    tenantId: tenant._id.toString(),
                    contactId: order.contactId,
                    text: `${bodyText}\n\n👉 Pay Now: ${paymentLink.short_url}`,
                    isMe: true,
                    time: new Date().toISOString(),
                    messageType: 'text',
                    status: 'sent',
                }).catch(() => {});
            }
        }

        if (io) {
            io.to(tenant._id.toString()).emit('catalog_order_payment_link_sent', {
                orderId: order._id.toString(),
                contactId: order.contactId,
                paymentLinkUrl: paymentLink.short_url,
                totalAmount: order.totalAmount,
                currency,
            });
        }

        return {
            success: true,
            paymentLinkId: paymentLink.id,
            paymentLinkUrl: paymentLink.short_url,
            orderId: order._id.toString(),
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
    }
};

module.exports = CatalogService;
