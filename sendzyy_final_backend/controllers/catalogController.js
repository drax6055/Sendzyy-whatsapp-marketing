const CatalogService = require('../services/CatalogService');
const WhatsAppOrder = require('../models/WhatsAppOrder');

/**
 * Controller for WhatsApp Catalog management, products, commerce settings, and messaging
 */
function createCatalogController(dependencies = {}) {
    const { Tenant } = dependencies;

    async function getTenantOr404(req, res) {
        const tenantId = req.user?.tenantId;
        if (!tenantId) {
            res.status(401).json({ success: false, error: 'Unauthorized: missing tenantId in token' });
            return null;
        }
        const tenant = await Tenant.findById(tenantId);
        if (!tenant) {
            res.status(404).json({ success: false, error: 'Tenant not found' });
            return null;
        }
        return tenant;
    }

    function extractMetaError(err) {
        const errorData = err.response?.data?.error;
        if (errorData) {
            if (errorData.error_user_msg) return errorData.error_user_msg;
            if (errorData.error_data?.details) return `${errorData.message} (${errorData.error_data.details})`;
            if (errorData.message) return errorData.message;
        }
        return err.message || 'An error occurred';
    }

    return {
        // GET /api/catalog/catalogs
        async getCatalogs(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                let catalogs = Array.isArray(tenant.whatsappConfig?.catalogs) ? tenant.whatsappConfig.catalogs : [];
                let activeCatalogId = tenant.whatsappConfig?.catalogId || (catalogs[0]?.catalogId || null);

                // Auto-connect with Meta if no catalog is currently loaded
                if (!activeCatalogId || catalogs.length === 0) {
                    try {
                        const syncResult = await CatalogService.syncCatalogs(tenant);
                        if (syncResult && Array.isArray(syncResult.catalogs) && syncResult.catalogs.length > 0) {
                            catalogs = syncResult.catalogs;
                            activeCatalogId = syncResult.catalogId || activeCatalogId;
                        }
                    } catch (syncErr) {
                        console.warn('[CatalogController] Auto-connect syncCatalogs warning:', syncErr.message);
                    }
                }

                // If activeCatalogId is set but catalogs list was empty, synthesize catalog entry so it never disconnects
                if (activeCatalogId && (!catalogs || catalogs.length === 0)) {
                    catalogs = [{
                        catalogId: activeCatalogId,
                        name: `Connected Catalog (${activeCatalogId})`,
                        vertical: 'commerce',
                        isDefault: true,
                    }];
                }

                res.json({
                    success: true,
                    catalogId: activeCatalogId,
                    catalogs,
                });
            } catch (err) {
                console.error('[CatalogController] getCatalogs error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/sync
        async syncCatalogs(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const result = await CatalogService.syncCatalogs(tenant);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] syncCatalogs error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/catalogs/select
        async selectCatalog(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const { catalogId, name } = req.body;
                if (!catalogId) {
                    return res.status(400).json({ success: false, error: 'catalogId is required' });
                }

                const result = await CatalogService.selectCatalog(tenant, catalogId, name);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] selectCatalog error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // DELETE /api/catalog/catalogs/:catalogId
        async removeCatalog(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const { catalogId } = req.params;
                if (!catalogId) {
                    return res.status(400).json({ success: false, error: 'catalogId is required' });
                }

                const result = await CatalogService.removeCatalog(tenant, catalogId);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] removeCatalog error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // GET /api/catalog/commerce-settings
        async getCommerceSettings(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const settings = await CatalogService.getCommerceSettings(tenant);
                res.json(settings);
            } catch (err) {
                console.error('[CatalogController] getCommerceSettings error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/commerce-settings
        async updateCommerceSettings(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const result = await CatalogService.updateCommerceSettings(tenant, req.body);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] updateCommerceSettings error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // GET /api/catalog/products
        async getProducts(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const result = await CatalogService.getProducts(tenant, {
                    catalogId: req.query.catalogId,
                    limit: req.query.limit,
                    after: req.query.after,
                    searchQuery: req.query.q || req.query.searchQuery,
                });

                res.json(result);
            } catch (err) {
                console.error('[CatalogController] getProducts error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/products
        async addProduct(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const product = await CatalogService.addProduct(tenant, req.body);
                res.status(201).json(product);
            } catch (err) {
                console.error('[CatalogController] addProduct error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/send-catalog-message
        async sendCatalogMessage(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const result = await CatalogService.sendCatalogMessage(dependencies, tenant, req.body);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] sendCatalogMessage error:', err);
                res.status(err.response?.status || 500).json({ success: false, error: extractMetaError(err) });
            }
        },

        // POST /api/catalog/send-single-product
        async sendSingleProduct(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const result = await CatalogService.sendSingleProduct(dependencies, tenant, req.body);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] sendSingleProduct error:', err);
                res.status(err.response?.status || 500).json({ success: false, error: extractMetaError(err) });
            }
        },

        // POST /api/catalog/send-multi-product
        async sendMultiProduct(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const result = await CatalogService.sendMultiProduct(dependencies, tenant, req.body);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] sendMultiProduct error:', err);
                res.status(err.response?.status || 500).json({ success: false, error: extractMetaError(err) });
            }
        },

        // POST /api/catalog/send-carousel
        async sendCarousel(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const result = await CatalogService.sendCarousel(dependencies, tenant, req.body);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] sendCarousel error:', err);
                res.status(err.response?.status || 500).json({ success: false, error: extractMetaError(err) });
            }
        },

        // GET /api/catalog/orders
        async getOrders(req, res) {
            try {
                const tenantId = req.user?.tenantId;
                if (!tenantId) return res.status(401).json({ success: false, error: 'Unauthorized' });

                const limit = parseInt(req.query.limit, 10) || 50;
                const status = req.query.status;
                const contactId = req.query.contactId;

                const query = { tenantId };
                if (status) query.status = status;
                if (contactId) query.contactId = contactId;

                // Auto-recover any order payloads from WebhookRawLog that missed WhatsAppOrder insertion
                try {
                    const WebhookRawLog = require('../models/WebhookRawLog');
                    const tenant = await Tenant.findById(tenantId);
                    const phoneId = tenant?.whatsappConfig?.phoneNumberId;
                    if (phoneId) {
                        const rawLogs = await WebhookRawLog.find({
                            "payload.entry.changes.value.metadata.phone_number_id": phoneId,
                            "payload.entry.changes.value.messages.type": "order",
                            createdAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
                        }).lean();

                        for (const rawLog of rawLogs) {
                            try {
                                const change = rawLog.payload?.entry?.[0]?.changes?.[0]?.value;
                                const msg = change?.messages?.[0];
                                const contacts = change?.contacts;
                                if (msg && msg.type === 'order') {
                                    const wamid = msg.id || '';
                                    if (wamid) {
                                        const exists = await WhatsAppOrder.findOne({ wamid }).lean();
                                        if (!exists) {
                                            const order = msg.order || {};
                                            const catalogId = order.catalog_id || tenant?.whatsappConfig?.catalogId || '';
                                            const productItems = (order.product_items || []).map(item => ({
                                                productRetailerId: item.product_retailer_id,
                                                quantity: Number(item.quantity) || 1,
                                                itemPrice: Number(item.item_price) || 0,
                                                currency: item.currency || 'INR',
                                            }));
                                            const totalAmount = productItems.reduce((sum, i) => sum + (i.itemPrice * i.quantity), 0);
                                            await WhatsAppOrder.create({
                                                tenantId,
                                                contactId: msg.from,
                                                contactName: contacts?.[0]?.profile?.name || '',
                                                catalogId,
                                                wamid,
                                                customerNote: order.text || '',
                                                items: productItems,
                                                totalAmount,
                                                currency: productItems[0]?.currency || 'INR',
                                                status: 'received',
                                                paymentStatus: 'pending',
                                                rawOrderPayload: order,
                                            });
                                        }
                                    }
                                }
                            } catch (ingestErr) {
                                console.warn('[CatalogController] Auto-recover order warning:', ingestErr.message);
                            }
                        }
                    }
                } catch (recErr) {
                    console.warn('[CatalogController] Order auto-recovery sweep warning:', recErr.message);
                }

                let orders = await WhatsAppOrder.find(query).sort({ createdAt: -1 }).limit(limit);

                // Auto-reconcile recent pending orders that have a Razorpay paymentLinkId
                const pendingWithLink = orders.filter(o =>
                    o.paymentStatus !== 'paid' &&
                    o.paymentLinkId &&
                    (Date.now() - new Date(o.createdAt || Date.now()).getTime()) < 14 * 24 * 60 * 60 * 1000
                ).slice(0, 10);

                if (pendingWithLink.length > 0) {
                    try {
                        const tenant = await Tenant.findById(tenantId);
                        const RazorpayClass = require('razorpay');
                        const customKeyId = tenant?.whatsappConfig?.commerceSettings?.razorpayKeyId;
                        const customKeySecret = tenant?.whatsappConfig?.commerceSettings?.razorpayKeySecret;

                        let rzp = null;
                        if (customKeyId && customKeySecret) {
                            rzp = new RazorpayClass({ key_id: customKeyId, key_secret: customKeySecret });
                        } else if (dependencies.razorpay) {
                            rzp = dependencies.razorpay;
                        } else if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
                            rzp = new RazorpayClass({ key_id: process.env.RAZORPAY_KEY_ID, key_secret: process.env.RAZORPAY_KEY_SECRET });
                        }

                        if (rzp) {
                            for (const order of pendingWithLink) {
                                try {
                                    const plink = await rzp.paymentLink.fetch(order.paymentLinkId);
                                    if (plink && (plink.status === 'paid' || (plink.amount_paid && plink.amount_paid >= plink.amount))) {
                                        const payId = (Array.isArray(plink.payments) && plink.payments[0]?.payment_id) || plink.id;
                                        await CatalogService.handlePaymentSuccess(dependencies, {
                                            orderId: order._id.toString(),
                                            paymentId: payId,
                                        });
                                        order.paymentStatus = 'paid';
                                        order.status = 'accepted';
                                        order.paymentId = payId;
                                        order.paidAt = new Date();
                                    }
                                } catch (pErr) {
                                    // Individual fetch failed or not paid yet
                                }
                            }
                        }
                    } catch (rzpErr) {
                        console.warn('[CatalogController] Payment link reconciliation warning:', rzpErr.message);
                    }
                }

                const finalOrders = orders.map(o => o.toObject ? o.toObject() : o);
                res.json({ success: true, orders: finalOrders, count: finalOrders.length });
            } catch (err) {
                console.error('[CatalogController] getOrders error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // PATCH /api/catalog/orders/:id/status
        async updateOrderStatus(req, res) {
            try {
                const tenantId = req.user?.tenantId;
                const { id } = req.params;
                const { status } = req.body;

                const allowed = ['received', 'accepted', 'processing', 'completed', 'cancelled'];
                if (!allowed.includes(status)) {
                    return res.status(400).json({ success: false, error: `Invalid status. Must be one of: ${allowed.join(', ')}` });
                }

                const order = await WhatsAppOrder.findOneAndUpdate(
                    { _id: id, tenantId },
                    { status },
                    { new: true }
                );

                if (!order) {
                    return res.status(404).json({ success: false, error: 'Order not found' });
                }

                res.json({ success: true, order });
            } catch (err) {
                console.error('[CatalogController] updateOrderStatus error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/orders/:id/send-payment-link
        async sendPaymentLink(req, res) {
            try {
                const tenantId = req.user?.tenantId;
                const { id } = req.params;

                const order = await WhatsAppOrder.findOne({ _id: id, tenantId });
                if (!order) {
                    return res.status(404).json({ success: false, error: 'Order not found' });
                }

                const tenant = await Tenant.findById(tenantId);
                if (!tenant) {
                    return res.status(404).json({ success: false, error: 'Tenant not found' });
                }

                const result = await CatalogService.sendPaymentLinkForOrder(dependencies, tenant, order);
                res.json({ success: true, ...result });
            } catch (err) {
                console.error('[CatalogController] sendPaymentLink error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/orders/:id/mark-paid
        async markOrderPaid(req, res) {
            try {
                const tenantId = req.user?.tenantId;
                const { id } = req.params;
                const { paymentId } = req.body;

                const order = await WhatsAppOrder.findOne({ _id: id, tenantId });
                if (!order) {
                    return res.status(404).json({ success: false, error: 'Order not found' });
                }

                const result = await CatalogService.handlePaymentSuccess(dependencies, {
                    orderId: id,
                    paymentId: paymentId || 'manual',
                });
                res.json({ success: true, ...result });
            } catch (err) {
                console.error('[CatalogController] markOrderPaid error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/payment-webhook (Razorpay Webhook for Order Payment Links)
        async handlePaymentWebhook(req, res) {
            try {
                const event = req.body?.event;
                const payload = req.body?.payload;

                let orderId = null;
                let paymentId = null;
                let failureReason = null;

                if (payload?.payment_link?.entity?.notes?.orderId) {
                    orderId = payload.payment_link.entity.notes.orderId;
                    paymentId = payload?.payment?.entity?.id || payload.payment_link.entity.id;
                    failureReason = payload?.payment?.entity?.error_description || payload?.payment?.entity?.error_reason;
                } else if (payload?.payment?.entity?.notes?.orderId) {
                    orderId = payload.payment.entity.notes.orderId;
                    paymentId = payload.payment.entity.id;
                    failureReason = payload.payment.entity.error_description || payload.payment.entity.error_reason;
                }

                if (orderId) {
                    const isFailure = event === 'payment.failed' ||
                                      event === 'payment_link.cancelled' ||
                                      event === 'payment_link.expired';

                    if (isFailure) {
                        await CatalogService.handlePaymentFailure(dependencies, {
                            orderId,
                            paymentId,
                            reason: failureReason || (event === 'payment_link.expired' ? 'Payment link expired' : 'Payment cancelled'),
                        });
                    } else {
                        await CatalogService.handlePaymentSuccess(dependencies, {
                            orderId,
                            paymentId,
                        });
                    }
                }

                res.json({ status: 'ok' });
            } catch (err) {
                console.error('[CatalogController] handlePaymentWebhook error:', err);
                res.status(200).json({ status: 'error', message: err.message });
            }
        },

        // POST /api/catalog/cashfree-webhook (Cashfree Webhook for Order Payment Events)
        async handleCashfreeWebhook(req, res) {
            try {
                const { data, type } = req.body || {};
                console.log(`[CatalogController] Cashfree Webhook received: ${type}`);

                if (type === 'PAYMENT_SUCCESS_WEBHOOK' || type === 'PAYMENT_SUCCESS') {
                    const rawOrderId = data?.order?.order_id || '';
                    let mongoOrderId = null;
                    const match = rawOrderId.match(/^order_([a-f0-9]{24})/i);
                    if (match && match[1]) {
                        mongoOrderId = match[1];
                    } else if (rawOrderId.startsWith('order_')) {
                        mongoOrderId = rawOrderId.replace('order_', '').split('_')[0];
                    }

                    const paymentId = data?.payment?.cf_payment_id || data?.payment?.payment_id || `cf_${Date.now()}`;

                    if (mongoOrderId) {
                        await CatalogService.handlePaymentSuccess(dependencies, {
                            orderId: mongoOrderId,
                            paymentId: String(paymentId),
                        });
                    }
                } else if (type === 'PAYMENT_FAILED_WEBHOOK' || type === 'PAYMENT_FAILED') {
                    const rawOrderId = data?.order?.order_id || '';
                    const match = rawOrderId.match(/^order_([a-f0-9]{24})/i);
                    const mongoOrderId = match ? match[1] : rawOrderId.replace('order_', '').split('_')[0];
                    const reason = data?.payment?.payment_message || 'Payment failed';
                    if (mongoOrderId) {
                        await CatalogService.handlePaymentFailure(dependencies, {
                            orderId: mongoOrderId,
                            reason,
                            paymentId: String(data?.payment?.cf_payment_id || ''),
                        });
                    }
                }

                res.json({ status: 'ok' });
            } catch (err) {
                console.error('[CatalogController] handleCashfreeWebhook error:', err);
                res.status(200).json({ status: 'error', message: err.message });
            }
        },

        // POST /api/catalog/orders/:id/verify-payment
        async verifyOrderPayment(req, res) {
            try {
                const tenantId = req.user?.tenantId;
                const { id } = req.params;

                const order = await WhatsAppOrder.findOne({ _id: id, tenantId });
                if (!order) {
                    return res.status(404).json({ success: false, error: 'Order not found' });
                }

                if (order.paymentStatus === 'paid') {
                    return res.json({ success: true, message: 'Order is already marked as paid', order });
                }

                // Cashfree Order Verification
                if (order.paymentProvider === 'cashfree' && process.env.CASHFREE_APP_ID && process.env.CASHFREE_SECRET_KEY) {
                    try {
                        const axios = require('axios');
                        const cfOrderId = order.cashfreeOrderId || order.paymentLinkId;
                        const cfRes = await axios.get(`https://api.cashfree.com/pg/orders/${cfOrderId}`, {
                            headers: {
                                'x-client-id': process.env.CASHFREE_APP_ID,
                                'x-client-secret': process.env.CASHFREE_SECRET_KEY,
                                'x-api-version': '2023-08-01'
                            },
                            timeout: 10000
                        });
                        if (cfRes.data?.order_status === 'PAID') {
                            const payId = cfRes.data?.cf_order_id || `cf_${Date.now()}`;
                            const result = await CatalogService.handlePaymentSuccess(dependencies, {
                                orderId: order._id.toString(),
                                paymentId: String(payId),
                            });
                            const updated = await WhatsAppOrder.findById(id).lean();
                            return res.json({ success: true, message: 'Cashfree payment verified! Order confirmed.', order: updated, ...result });
                        }
                    } catch (cfErr) {
                        console.error('[CatalogController] verify Cashfree payment notice:', cfErr.message);
                    }
                }

                // Direct UPI Order Verification
                if (order.paymentProvider === 'upi' || order.paymentLinkId?.startsWith('upi_')) {
                    const payId = order.customerReportedUtr || order.paymentId || `upi_manual_${Date.now()}`;
                    const result = await CatalogService.handlePaymentSuccess(dependencies, {
                        orderId: order._id.toString(),
                        paymentId: payId,
                    });
                    const updated = await WhatsAppOrder.findById(id).lean();
                    return res.json({
                        success: true,
                        message: 'Direct UPI payment verified! Order confirmed.',
                        order: updated,
                        ...result
                    });
                }

                if (!order.paymentLinkId) {
                    return res.status(400).json({ success: false, error: 'Order does not have a payment link' });
                }

                const tenant = await Tenant.findById(tenantId);
                const RazorpayClass = require('razorpay');
                const customKeyId = tenant?.whatsappConfig?.commerceSettings?.razorpayKeyId;
                const customKeySecret = tenant?.whatsappConfig?.commerceSettings?.razorpayKeySecret;

                let rzp = null;
                if (customKeyId && customKeySecret) {
                    rzp = new RazorpayClass({ key_id: customKeyId, key_secret: customKeySecret });
                } else if (dependencies.razorpay) {
                    rzp = dependencies.razorpay;
                } else if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
                    rzp = new RazorpayClass({ key_id: process.env.RAZORPAY_KEY_ID, key_secret: process.env.RAZORPAY_KEY_SECRET });
                }

                if (!rzp) {
                    return res.status(400).json({ success: false, error: 'Razorpay not configured' });
                }

                const plink = await rzp.paymentLink.fetch(order.paymentLinkId);
                if (plink && (plink.status === 'paid' || (plink.amount_paid && plink.amount_paid >= plink.amount))) {
                    const payId = (Array.isArray(plink.payments) && plink.payments[0]?.payment_id) || plink.id;
                    const result = await CatalogService.handlePaymentSuccess(dependencies, {
                        orderId: order._id.toString(),
                        paymentId: payId,
                    });
                    const updated = await WhatsAppOrder.findById(id).lean();
                    return res.json({ success: true, message: 'Payment verified and order marked as paid', order: updated, ...result });
                }

                res.json({
                    success: false,
                    message: `Payment status on Razorpay is currently: ${plink?.status || 'unpaid'}`,
                    order,
                });
            } catch (err) {
                console.error('[CatalogController] verifyOrderPayment error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // GET /api/catalog/payout-settings (Option B: Bank Settlement / Payout Details)
        async getPayoutSettings(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const cfg = tenant.payoutConfig || {};
                const rawAcc = cfg.accountNumber || '';
                const maskedAcc = rawAcc.length > 4 ? `••••••••${rawAcc.slice(-4)}` : rawAcc;

                res.json({
                    success: true,
                    payoutSettings: {
                        accountHolderName: cfg.accountHolderName || '',
                        accountNumber: maskedAcc,
                        rawAccountNumberExists: Boolean(rawAcc && rawAcc.length >= 6),
                        ifscCode: cfg.ifscCode || '',
                        bankName: cfg.bankName || '',
                        upiId: cfg.upiId || '',
                        businessName: cfg.businessName || tenant.name || '',
                        enabled: cfg.enabled !== false,
                        autoSendOnOrder: cfg.autoSendOnOrder !== false,
                        razorpayAccountId: cfg.razorpayAccountId || '',
                        cashfreeVendorId: cfg.cashfreeVendorId || '',
                    }
                });
            } catch (err) {
                console.error('[CatalogController] getPayoutSettings error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/payout-settings (Option B: Save Bank Settlement / Payout Details)
        async updatePayoutSettings(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const {
                    accountHolderName,
                    accountNumber,
                    ifscCode,
                    bankName,
                    upiId,
                    businessName,
                    enabled,
                    autoSendOnOrder,
                    razorpayAccountId
                } = req.body;

                if (!tenant.payoutConfig) {
                    tenant.payoutConfig = {};
                }

                if (typeof razorpayAccountId === 'string') {
                    tenant.payoutConfig.razorpayAccountId = razorpayAccountId.trim();
                }

                if (ifscCode) {
                    const cleanIfsc = String(ifscCode).trim().toUpperCase();
                    if (cleanIfsc.length > 0) {
                        const ifscRegex = /^[A-Z]{4}0[A-Z0-9]{6}$/;
                        if (!ifscRegex.test(cleanIfsc)) {
                            return res.status(400).json({
                                success: false,
                                error: 'Invalid IFSC Code. Must be 11 characters (e.g. HDFC0001234, SBIN0004567).'
                            });
                        }
                        tenant.payoutConfig.ifscCode = cleanIfsc;
                    } else {
                        tenant.payoutConfig.ifscCode = '';
                    }
                } else if (ifscCode === '') {
                    tenant.payoutConfig.ifscCode = '';
                }

                if (accountNumber !== undefined && !accountNumber.includes('•')) {
                    const cleanAcc = String(accountNumber).trim().replace(/\s+/g, '');
                    if (cleanAcc.length > 0) {
                        if (cleanAcc.length < 6 || cleanAcc.length > 22) {
                            return res.status(400).json({
                                success: false,
                                error: 'Invalid Bank Account Number (must be between 6 and 22 digits).'
                            });
                        }
                        tenant.payoutConfig.accountNumber = cleanAcc;
                    } else {
                        tenant.payoutConfig.accountNumber = '';
                    }
                }

                if (typeof accountHolderName === 'string') tenant.payoutConfig.accountHolderName = accountHolderName.trim();
                if (typeof bankName === 'string') tenant.payoutConfig.bankName = bankName.trim();
                if (typeof businessName === 'string') tenant.payoutConfig.businessName = businessName.trim();
                if (typeof enabled === 'boolean') tenant.payoutConfig.enabled = enabled;
                if (typeof autoSendOnOrder === 'boolean') tenant.payoutConfig.autoSendOnOrder = autoSendOnOrder;

                if (typeof upiId === 'string') {
                    const cleanUpi = upiId.trim();
                    tenant.payoutConfig.upiId = cleanUpi;
                    if (!tenant.upiPaymentConfig) tenant.upiPaymentConfig = {};
                    tenant.upiPaymentConfig.upiId = cleanUpi;
                    tenant.upiPaymentConfig.businessName = tenant.payoutConfig.businessName || tenant.name;
                    tenant.upiPaymentConfig.enabled = tenant.payoutConfig.enabled !== false;
                    tenant.upiPaymentConfig.autoSendOnOrder = tenant.payoutConfig.autoSendOnOrder !== false;
                }

                // Try linking with Razorpay Route Linked Account if master Razorpay is configured
                if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET && !tenant.payoutConfig.razorpayAccountId && tenant.payoutConfig.accountNumber && tenant.payoutConfig.ifscCode) {
                    try {
                        const axios = require('axios');
                        const auth = Buffer.from(`${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`).toString('base64');
                        const rawPhone = String(tenant.phone || '').replace(/[^0-9]/g, '');
                        const cleanPhone = rawPhone.length >= 10 ? rawPhone.slice(-10) : '9876543210';
                        const routeRes = await axios.post('https://api.razorpay.com/v2/accounts', {
                            email: tenant.email || `tenant_${tenant._id}@sendzyy.com`,
                            phone: cleanPhone,
                            legal_business_name: tenant.payoutConfig.businessName || tenant.name,
                            customer_facing_business_name: tenant.payoutConfig.businessName || tenant.name,
                            business_type: 'individual',
                            contact_name: tenant.payoutConfig.accountHolderName || tenant.name,
                            profile: {
                                category: 'ecommerce',
                                subcategory: 'other'
                            },
                            instrument: {
                                type: 'bank_account',
                                bank_account: {
                                    beneficiary_name: tenant.payoutConfig.accountHolderName || tenant.payoutConfig.businessName || tenant.name,
                                    account_number: tenant.payoutConfig.accountNumber,
                                    ifsc_code: tenant.payoutConfig.ifscCode,
                                }
                            }
                        }, {
                            headers: {
                                'Authorization': `Basic ${auth}`,
                                'Content-Type': 'application/json'
                            },
                            timeout: 10000
                        });
                        if (routeRes.data?.id) {
                            tenant.payoutConfig.razorpayAccountId = routeRes.data.id;
                            console.log(`[Catalog] Created Razorpay Route account ${routeRes.data.id} for tenant ${tenant._id}`);
                        }
                    } catch (routeErr) {
                        console.log('[Catalog] Razorpay Route auto-create notice:', routeErr.response?.data?.error?.description || routeErr.message);
                    }
                }

                // Sync with Cashfree Easy Split Vendor
                if (process.env.CASHFREE_APP_ID && process.env.CASHFREE_SECRET_KEY && tenant.payoutConfig.accountNumber && tenant.payoutConfig.ifscCode) {
                    try {
                        const axios = require('axios');
                        const rawPhone = String(tenant.phone || '').replace(/[^0-9]/g, '');
                        const cleanPhone = rawPhone.length >= 10 ? rawPhone.slice(-10) : '9876543210';
                        const vendorId = `tenant_${tenant._id}`;
                        const cfRes = await axios.post('https://api.cashfree.com/pg/easy-split/vendors', {
                            vendor_id: vendorId,
                            status: 'ACTIVE',
                            name: tenant.payoutConfig.businessName || tenant.name,
                            email: tenant.email || `tenant_${tenant._id}@sendzyy.com`,
                            phone: cleanPhone,
                            bank: {
                                account_number: tenant.payoutConfig.accountNumber,
                                account_holder: tenant.payoutConfig.accountHolderName || tenant.payoutConfig.businessName || tenant.name,
                                ifsc: tenant.payoutConfig.ifscCode
                            },
                            kyc_details: {
                                account_type: 'Individual',
                                business_type: 'Social Media and Entertainment'
                            }
                        }, {
                            headers: {
                                'x-client-id': process.env.CASHFREE_APP_ID,
                                'x-client-secret': process.env.CASHFREE_SECRET_KEY,
                                'x-api-version': '2023-08-01',
                                'Content-Type': 'application/json'
                            },
                            timeout: 10000
                        });
                        if (cfRes.data?.vendor_id) {
                            tenant.payoutConfig.cashfreeVendorId = cfRes.data.vendor_id;
                            console.log(`[Catalog] Created Cashfree Easy Split vendor ${cfRes.data.vendor_id} for tenant ${tenant._id}`);
                        }
                    } catch (cfErr) {
                        console.log('[Catalog] Cashfree Easy Split vendor sync notice:', cfErr.response?.data?.message || cfErr.message);
                    }
                }

                tenant.markModified('payoutConfig');
                await tenant.save();

                const rawAcc = tenant.payoutConfig.accountNumber || '';
                res.json({
                    success: true,
                    message: 'Bank settlement details saved successfully!',
                    payoutSettings: {
                        accountHolderName: tenant.payoutConfig.accountHolderName || '',
                        accountNumber: rawAcc.length > 4 ? `••••••••${rawAcc.slice(-4)}` : rawAcc,
                        ifscCode: tenant.payoutConfig.ifscCode || '',
                        bankName: tenant.payoutConfig.bankName || '',
                        upiId: tenant.payoutConfig.upiId || '',
                        businessName: tenant.payoutConfig.businessName || '',
                        enabled: tenant.payoutConfig.enabled !== false,
                        autoSendOnOrder: tenant.payoutConfig.autoSendOnOrder !== false,
                        razorpayAccountId: tenant.payoutConfig.razorpayAccountId || '',
                        cashfreeVendorId: tenant.payoutConfig.cashfreeVendorId || '',
                    }
                });
            } catch (err) {
                console.error('[CatalogController] updatePayoutSettings error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // GET /api/catalog/upi-settings
        async getUpiSettings(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const upiSettings = tenant.upiPaymentConfig || {
                    upiId: '',
                    businessName: tenant.name || '',
                    enabled: false,
                    autoSendOnOrder: true,
                };

                res.json({ success: true, upiSettings });
            } catch (err) {
                console.error('[CatalogController] getUpiSettings error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // POST /api/catalog/upi-settings
        async updateUpiSettings(req, res) {
            try {
                const tenant = await getTenantOr404(req, res);
                if (!tenant) return;

                const { upiId, businessName, enabled, autoSendOnOrder } = req.body;

                if (enabled && upiId) {
                    const cleanUpi = String(upiId).trim();
                    if (!cleanUpi.includes('@') || cleanUpi.length < 5) {
                        return res.status(400).json({
                            success: false,
                            error: 'Invalid UPI ID format. Example: yourname@bank or 9876543210@paytm'
                        });
                    }
                }

                if (!tenant.upiPaymentConfig) {
                    tenant.upiPaymentConfig = {};
                }

                if (typeof upiId === 'string') tenant.upiPaymentConfig.upiId = upiId.trim();
                if (typeof businessName === 'string') tenant.upiPaymentConfig.businessName = businessName.trim();
                if (typeof enabled === 'boolean') tenant.upiPaymentConfig.enabled = enabled;
                if (typeof autoSendOnOrder === 'boolean') tenant.upiPaymentConfig.autoSendOnOrder = autoSendOnOrder;

                tenant.markModified('upiPaymentConfig');
                await tenant.save();

                res.json({
                    success: true,
                    message: 'UPI payment settings updated successfully',
                    upiSettings: tenant.upiPaymentConfig,
                });
            } catch (err) {
                console.error('[CatalogController] updateUpiSettings error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // GET /pay/upi/:orderId (Public Customer UPI Payment Landing Page)
        async renderUpiPaymentPage(req, res) {
            try {
                const { orderId } = req.params;
                const order = await WhatsAppOrder.findById(orderId);
                if (!order) {
                    return res.status(404).send(`<!DOCTYPE html><html><body style="font-family:sans-serif;text-align:center;padding:50px;"><h2>Order Not Found</h2><p>This order link is invalid or expired.</p></body></html>`);
                }

                const tenant = await Tenant.findById(order.tenantId);
                const dest = CatalogService.getTenantPaymentDestination(tenant);
                if (!dest) {
                    return res.status(400).send(`<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;text-align:center;padding:50px 20px;background:#0F172A;color:white;"><h2>Payment Destination Not Configured</h2><p style="color:#94A3B8;">The seller has not configured their bank account or UPI ID yet. Please contact the seller directly on WhatsApp.</p></body></html>`);
                }

                const upiId = dest.upiId;
                const storeName = dest.merchantName || 'Sendzyy Store';
                const orderCode = order._id.toString().slice(-6).toUpperCase();
                const currency = order.currency || 'INR';
                const totalAmount = order.totalAmount.toFixed(2);
                const isPaid = order.paymentStatus === 'paid';

                if (isPaid) {
                    return res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Payment Received - ${storeName}</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B1120; min-height: 100vh; display: flex; align-items: center; justify-content: center; margin: 0; padding: 20px; color: #1E293B; }
    .card { background: white; border-radius: 28px; padding: 36px 28px; max-width: 440px; width: 100%; text-align: center; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.4); }
    .badge { width: 76px; height: 76px; background: #DCFCE7; color: #16A34A; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 40px; margin: 0 auto 20px; font-weight: bold; }
    h2 { margin: 0 0 8px; font-size: 24px; color: #0F172A; font-weight: 800; }
    .sub { color: #64748B; font-size: 14px; margin-bottom: 24px; }
    .details { background: #F8FAFC; border-radius: 18px; padding: 18px 20px; text-align: left; margin-bottom: 24px; border: 1px solid #E2E8F0; }
    .row { display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 14px; color: #475569; }
    .row:last-child { margin-bottom: 0; padding-top: 10px; border-top: 1px dashed #CBD5E1; font-weight: 800; color: #0F172A; }
    .btn { display: block; background: #25D366; color: white; padding: 15px 20px; border-radius: 16px; text-decoration: none; font-weight: 700; font-size: 15px; box-shadow: 0 10px 20px rgba(37,211,102,0.25); }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">✓</div>
    <h2>Payment Confirmed!</h2>
    <p class="sub">Thank you for your order with <strong>${storeName}</strong>.</p>
    <div class="details">
      <div class="row"><span>Order ID</span><span>#${orderCode}</span></div>
      <div class="row"><span>Items</span><span>${order.items?.length || 0} items</span></div>
      <div class="row"><span>Status</span><span style="color:#16A34A;font-weight:700;">PAID ✓</span></div>
      <div class="row"><span>Total Paid</span><span>${currency} ${totalAmount}</span></div>
    </div>
    <a href="https://web.whatsapp.com" class="btn">Return to WhatsApp</a>
  </div>
</body>
</html>`);
                }

                // Construct standard NPCI UPI Intent URLs
                const upiUrl = `upi://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(storeName)}&am=${totalAmount}&tr=${orderCode}&tn=Order%20${orderCode}&cu=INR`;
                const gpayUrl = `upi://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(storeName)}&am=${totalAmount}&tr=${orderCode}&tn=Order%20${orderCode}&cu=INR`;
                const phonepeUrl = `phonepe://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(storeName)}&am=${totalAmount}&tr=${orderCode}&tn=Order%20${orderCode}&cu=INR`;
                const paytmUrl = `paytmmp://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(storeName)}&am=${totalAmount}&tr=${orderCode}&tn=Order%20${orderCode}&cu=INR`;
                const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=10&data=${encodeURIComponent(upiUrl)}`;

                const isBank = dest.type === 'bank';

                res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <title>Pay ${currency} ${totalAmount} - ${storeName}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    body { font-family: "Outfit", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B1120; min-height: 100vh; margin: 0; padding: 24px 16px; display: flex; justify-content: center; align-items: flex-start; color: #0F172A; }
    .container { max-width: 440px; width: 100%; background: #FFFFFF; border-radius: 32px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); overflow: hidden; }
    .header { background: linear-gradient(135deg, #065F46 0%, #059669 50%, #10B981 100%); padding: 28px 24px; color: white; text-align: center; position: relative; }
    .store-badge { display: inline-flex; align-items: center; gap: 6px; background: rgba(255,255,255,0.22); backdrop-filter: blur(12px); padding: 5px 14px; border-radius: 20px; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 10px; border: 1px solid rgba(255,255,255,0.25); }
    .store-name { font-size: 22px; font-weight: 800; margin: 0 0 4px; letter-spacing: -0.3px; line-height: 1.25; }
    .amount-box { margin-top: 14px; background: rgba(255,255,255,0.16); backdrop-filter: blur(8px); border-radius: 20px; padding: 14px; border: 1px solid rgba(255,255,255,0.2); }
    .amount-label { font-size: 11px; font-weight: 600; opacity: 0.9; text-transform: uppercase; letter-spacing: 0.8px; }
    .amount-val { font-size: 34px; font-weight: 800; margin: 2px 0 0; letter-spacing: -0.5px; }
    .body { padding: 24px; }
    .order-info { background: #F8FAFC; border-radius: 18px; padding: 14px 16px; border: 1px solid #E2E8F0; margin-bottom: 20px; }
    .info-row { display: flex; justify-content: space-between; font-size: 13px; color: #64748B; margin-bottom: 6px; }
    .info-row:last-child { margin-bottom: 0; }
    .info-val { font-weight: 600; color: #0F172A; text-align: right; }
    
    .dest-card { background: #F0FDF4; border: 1.5px solid #86EFAC; border-radius: 20px; padding: 18px; margin-bottom: 20px; }
    .dest-tag { display: inline-block; font-size: 11px; font-weight: 700; color: #047857; text-transform: uppercase; letter-spacing: 0.6px; margin-bottom: 8px; background: #DCFCE7; padding: 3px 10px; border-radius: 8px; }
    .bank-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; }
    .bank-item { background: white; border: 1px solid #DCFCE7; border-radius: 12px; padding: 8px 10px; }
    .bank-label { font-size: 10px; color: #64748B; text-transform: uppercase; font-weight: 600; letter-spacing: 0.4px; }
    .bank-val { font-size: 13px; font-weight: 700; color: #0F172A; margin-top: 2px; word-break: break-all; }
    .bank-val.mono { font-family: "JetBrains Mono", monospace; font-size: 12px; color: #065F46; }

    .upi-box { background: white; border: 1px solid #86EFAC; border-radius: 14px; padding: 10px 12px; margin-top: 10px; display: flex; align-items: center; justify-content: space-between; gap: 8px; }
    .upi-text { font-family: "JetBrains Mono", monospace; font-size: 12px; font-weight: 700; color: #065F46; word-break: break-all; }
    .btn-copy { background: #059669; color: white; border: none; padding: 6px 12px; border-radius: 8px; font-size: 11px; font-weight: 700; cursor: pointer; white-space: nowrap; transition: 0.15s; font-family: inherit; }
    .btn-copy:hover { background: #047857; }

    .btn-pay { display: flex; align-items: center; justify-content: center; gap: 10px; background: #0F172A; color: white; text-decoration: none; padding: 16px 20px; border-radius: 18px; font-size: 16px; font-weight: 700; text-align: center; box-shadow: 0 10px 25px rgba(15,23,42,0.3); transition: transform 0.1s, box-shadow 0.1s; margin-bottom: 14px; }
    .btn-pay:active { transform: scale(0.98); }
    
    .app-buttons { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin-bottom: 22px; }
    .app-btn { background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 14px; padding: 10px 4px; text-align: center; text-decoration: none; color: #334155; font-size: 11px; font-weight: 700; transition: 0.15s; display: flex; flex-direction: column; align-items: center; gap: 4px; }
    .app-btn:hover { background: #F1F5F9; border-color: #CBD5E1; }
    .app-btn .icon { font-size: 18px; }

    .qr-card { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 22px; padding: 22px; text-align: center; margin-bottom: 22px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.02); }
    .qr-title { font-size: 13px; font-weight: 700; color: #334155; margin-bottom: 12px; }
    .qr-img { width: 200px; height: 200px; border-radius: 14px; border: 1px solid #E2E8F0; padding: 8px; background: white; }
    .qr-sub { font-size: 11px; color: #94A3B8; margin-top: 10px; font-weight: 500; }

    .reported-section { border-top: 1px solid #E2E8F0; padding-top: 20px; text-align: center; }
    .btn-reported { background: white; border: 1.5px solid #10B981; color: #059669; padding: 13px 18px; border-radius: 16px; font-weight: 700; font-size: 14px; width: 100%; cursor: pointer; transition: 0.2s; font-family: inherit; }
    .btn-reported:hover { background: #F0FDF4; }
    .utr-input { width: 100%; padding: 12px 16px; border-radius: 12px; border: 1.5px solid #CBD5E1; margin-bottom: 10px; font-size: 14px; box-sizing: border-box; text-align: center; display: none; font-family: "JetBrains Mono", monospace; font-weight: 600; letter-spacing: 1px; }
    .utr-input:focus { outline: none; border-color: #10B981; }
    .reported-msg { display: none; background: #ECFDF5; color: #065F46; padding: 14px 16px; border-radius: 14px; font-size: 13px; font-weight: 600; margin-top: 12px; border: 1px solid #A7F3D0; line-height: 1.4; }
    .footer { text-align: center; font-size: 11px; color: #94A3B8; padding-bottom: 22px; }

    .toast { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); background: #0F172A; color: white; padding: 10px 20px; border-radius: 20px; font-size: 12px; font-weight: 600; opacity: 0; pointer-events: none; transition: 0.25s; box-shadow: 0 10px 20px rgba(0,0,0,0.3); z-index: 99; }
    .toast.show { opacity: 1; transform: translateX(-50%) translateY(-10px); }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="store-badge">✓ Verified Direct Transfer</div>
      <div class="store-name">${storeName}</div>
      <div class="amount-box">
        <div class="amount-label">Amount Payable</div>
        <div class="amount-val">${currency} ${totalAmount}</div>
      </div>
    </div>
    
    <div class="body">
      <div class="order-info">
        <div class="info-row"><span>Order ID</span><span class="info-val">#${orderCode}</span></div>
        <div class="info-row"><span>Customer</span><span class="info-val">${order.contactName || 'Customer'}</span></div>
        <div class="info-row"><span>Items (${order.items?.length || 0})</span><span class="info-val">${order.items?.map(i => `${i.quantity}x ${i.productRetailerId}`).join(', ') || 'Catalog items'}</span></div>
      </div>

      <!-- Payment Destination Card -->
      <div class="dest-card">
        <span class="dest-tag">${isBank ? '🏦 Direct Bank Deposit via UPI' : '⚡ Direct UPI Transfer'}</span>
        ${isBank ? `
          <div class="bank-grid">
            <div class="bank-item">
              <div class="bank-label">Bank</div>
              <div class="bank-val">${dest.bankName}</div>
            </div>
            <div class="bank-item">
              <div class="bank-label">Beneficiary</div>
              <div class="bank-val">${dest.accountHolderName}</div>
            </div>
            <div class="bank-item">
              <div class="bank-label">Account No.</div>
              <div class="bank-val mono" id="accNumberVal">${dest.accountNumber}</div>
            </div>
            <div class="bank-item">
              <div class="bank-label">IFSC Code</div>
              <div class="bank-val mono" id="ifscVal">${dest.ifscCode}</div>
            </div>
          </div>
          <div class="upi-box">
            <span class="upi-text" id="upiVpaText">${upiId}</span>
            <button class="btn-copy" onclick="copyText('${upiId}', 'UPI ID')">Copy UPI</button>
          </div>
        ` : `
          <div class="upi-box">
            <span class="upi-text" id="upiVpaText">${upiId}</span>
            <button class="btn-copy" onclick="copyText('${upiId}', 'UPI ID')">Copy UPI</button>
          </div>
        `}
      </div>

      <!-- Primary UPI Intent CTA -->
      <a href="${upiUrl}" class="btn-pay" id="payBtn">
        <span>⚡ Open UPI App & Pay ₹${totalAmount}</span>
      </a>

      <!-- Quick Launch Apps -->
      <div class="app-buttons">
        <a href="${gpayUrl}" class="app-btn">
          <span class="icon">🟢</span>
          <span>Google Pay</span>
        </a>
        <a href="${phonepeUrl}" class="app-btn">
          <span class="icon">🟣</span>
          <span>PhonePe</span>
        </a>
        <a href="${paytmUrl}" class="app-btn">
          <span class="icon">🔵</span>
          <span>Paytm</span>
        </a>
        <a href="${upiUrl}" class="app-btn">
          <span class="icon">🇮🇳</span>
          <span>BHIM / Other</span>
        </a>
      </div>

      <!-- High-Res QR Code Scanner -->
      <div class="qr-card">
        <div class="qr-title">Or Scan QR from Any UPI App</div>
        <img src="${qrUrl}" alt="Direct UPI QR Code" class="qr-img">
        <div class="qr-sub">Instant 100% direct credit to seller's account • Zero fee</div>
      </div>

      <!-- Customer Payment Confirmation Form -->
      <div class="reported-section">
        <input type="text" id="utrInput" class="utr-input" placeholder="Enter 12-Digit UPI Ref / UTR" maxlength="20">
        <button class="btn-reported" id="reportBtn" onclick="toggleAndReport()">✓ I Have Paid to this Account</button>
        <div class="reported-msg" id="reportMsg">
          🎉 Payment submitted to seller! We are verifying and will send your confirmed receipt on WhatsApp shortly.
        </div>
      </div>
    </div>

    <div class="footer">
      Protected by WhatsApp Catalog & Direct Bank UPI
    </div>
  </div>

  <div class="toast" id="toast">Copied to clipboard!</div>

  <script>
    function showToast(msg) {
      const t = document.getElementById('toast');
      t.innerText = msg;
      t.classList.add('show');
      setTimeout(() => t.classList.remove('show'), 2000);
    }

    function copyText(val, label) {
      if (navigator.clipboard) {
        navigator.clipboard.writeText(val).then(() => showToast(label + ' copied!'));
      } else {
        showToast(label + ': ' + val);
      }
    }

    let utrShown = false;
    async function toggleAndReport() {
      const utrEl = document.getElementById('utrInput');
      const btn = document.getElementById('reportBtn');
      const msg = document.getElementById('reportMsg');

      if (!utrShown) {
        utrEl.style.display = 'block';
        utrEl.focus();
        btn.innerText = 'Submit Confirmation (UTR)';
        utrShown = true;
        return;
      }

      const utr = utrEl.value.trim();
      btn.disabled = true;
      btn.innerText = 'Submitting...';

      try {
        const res = await fetch('/api/catalog/orders/${order._id}/customer-reported-paid', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ utr: utr })
        });
        const data = await res.json();
        if (data.success) {
          utrEl.style.display = 'none';
          btn.style.display = 'none';
          msg.style.display = 'block';
        } else {
          alert(data.error || 'Failed to submit report');
          btn.disabled = false;
          btn.innerText = 'Submit Confirmation (UTR)';
        }
      } catch (err) {
        alert('Error submitting payment confirmation.');
        btn.disabled = false;
        btn.innerText = 'Submit Confirmation (UTR)';
      }
    }
  </script>
</body>
</html>`);
            } catch (err) {
                console.error('[CatalogController] renderUpiPaymentPage error:', err);
                res.status(500).send('Error loading payment page');
            }
        },

        // GET /pay/cashfree/:orderId (Public Customer Cashfree Hosted Checkout Page)
        async renderCashfreePaymentPage(req, res) {
            try {
                const { orderId } = req.params;
                const order = await WhatsAppOrder.findById(orderId);
                if (!order) {
                    return res.status(404).send(`<!DOCTYPE html><html><body style="font-family:sans-serif;text-align:center;padding:50px;"><h2>Order Not Found</h2><p>This order link is invalid or expired.</p></body></html>`);
                }

                const tenant = await Tenant.findById(order.tenantId);
                const storeName = tenant?.payoutConfig?.businessName || tenant?.name || 'Store';
                const orderCode = order._id.toString().slice(-6).toUpperCase();
                const currency = order.currency || 'INR';
                const isPaid = order.paymentStatus === 'paid';

                if (isPaid) {
                    return res.send(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Payment Received - ${storeName}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; background: #0F172A; color: white; }
    .card { background: #1E293B; border-radius: 24px; padding: 40px 32px; max-width: 420px; text-align: center; box-shadow: 0 20px 40px rgba(0,0,0,0.4); margin: 20px; border: 1px solid rgba(255,255,255,0.08); }
    .icon { width: 72px; height: 72px; background: #DCFCE7; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; color: #16A34A; font-size: 38px; font-weight: bold; }
    h2 { margin: 0 0 10px; color: white; }
    p { margin: 0 0 24px; color: #94A3B8; font-size: 15px; line-height: 1.5; }
    .btn { display: inline-block; background: #25D366; color: white; padding: 14px 28px; border-radius: 14px; text-decoration: none; font-weight: 700; font-size: 15px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h2>Payment Already Received!</h2>
    <p>Your payment for Order <strong>#${orderCode}</strong> has already been confirmed. Thank you for shopping with ${storeName}!</p>
    <a href="https://web.whatsapp.com" class="btn">Back to WhatsApp</a>
  </div>
</body>
</html>`);
                }

                const paymentSessionId = order.cashfreePaymentSessionId;
                if (!paymentSessionId) {
                    return res.status(400).send(`<!DOCTYPE html><html><body style="font-family:sans-serif;text-align:center;padding:50px;"><h2>Payment Session Expired</h2><p>Please request a new payment link from the store on WhatsApp.</p></body></html>`);
                }

                const isProduction = process.env.CASHFREE_ENV === 'PRODUCTION' || !process.env.CASHFREE_ENV;
                const mode = isProduction ? 'production' : 'sandbox';

                res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Pay ${currency} ${order.totalAmount.toFixed(2)} - ${storeName}</title>
  <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; background: #0F172A; color: white; text-align: center; }
    .spinner { border: 4px solid rgba(255, 255, 255, 0.1); border-left-color: #10B981; border-radius: 50%; width: 48px; height: 48px; animation: spin 0.8s linear infinite; margin: 0 auto 24px; }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    .card { background: #1E293B; border-radius: 24px; padding: 36px 28px; max-width: 400px; width: 90%; border: 1px solid rgba(255,255,255,0.08); box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
    h3 { margin: 0 0 8px 0; font-size: 20px; }
    p { color: #94A3B8; font-size: 14px; margin: 0 0 20px 0; line-height: 1.4; }
    .amount { font-size: 28px; font-weight: 800; color: #10B981; margin-bottom: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h3>Connecting to Payment Gateway...</h3>
    <div class="amount">${currency} ${order.totalAmount.toFixed(2)}</div>
    <p>Opening Google Pay, PhonePe, Paytm, UPI & Cards securely via Cashfree.</p>
  </div>
  <script>
    try {
      const cashfree = Cashfree({ mode: "${mode}" });
      cashfree.checkout({
        paymentSessionId: "${paymentSessionId}",
        redirectTarget: "_self"
      });
    } catch (e) {
      console.error(e);
      document.querySelector("p").innerText = "Redirect failed. Please refresh or contact the store.";
    }
  </script>
</body>
</html>`);
            } catch (err) {
                console.error('[CatalogController] renderCashfreePaymentPage error:', err);
                res.status(500).send('Error loading payment page');
            }
        },

        // POST /api/catalog/orders/:id/customer-reported-paid
        async customerReportedPaid(req, res) {
            try {
                const { id } = req.params;
                const { utr } = req.body;

                const order = await WhatsAppOrder.findById(id);
                if (!order) {
                    return res.status(404).json({ success: false, error: 'Order not found' });
                }

                order.customerReportedPaid = true;
                order.customerReportedAt = new Date();
                if (utr) {
                    order.customerReportedUtr = String(utr).trim();
                }
                if (order.paymentStatus !== 'paid') {
                    order.paymentStatus = 'customer_reported';
                }
                await order.save();

                // Alert the tenant's socket room
                if (dependencies.io) {
                    dependencies.io.to(order.tenantId.toString()).emit('catalog_order_payment_reported', {
                        orderId: order._id.toString(),
                        contactId: order.contactId,
                        customerReportedUtr: order.customerReportedUtr,
                        customerReportedAt: order.customerReportedAt,
                        totalAmount: order.totalAmount,
                        currency: order.currency,
                        status: order.paymentStatus,
                    });
                }

                res.json({ success: true, message: 'Payment reported successfully', order });
            } catch (err) {
                console.error('[CatalogController] customerReportedPaid error:', err);
                res.status(500).json({ success: false, error: err.message });
            }
        },

        // GET /catalog/order-success
        async handleOrderSuccessCallback(req, res) {
            try {
                const { orderId, razorpay_payment_id, razorpay_payment_link_id } = req.query;
                if (orderId) {
                    const payId = razorpay_payment_id || razorpay_payment_link_id || 'online';
                    await CatalogService.handlePaymentSuccess(dependencies, {
                        orderId,
                        paymentId: payId,
                    }).catch(e => console.warn('[CatalogController] Callback payment success warning:', e.message));
                }

                res.send(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Payment Successful - Sendzyy</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; background: #F3F4F6; }
    .card { background: white; border-radius: 20px; padding: 40px 32px; max-width: 420px; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.06); margin: 20px; }
    .icon { width: 64px; height: 64px; background: #D1FAE5; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; color: #10B981; font-size: 32px; font-weight: bold; }
    h2 { margin: 0 0 10px; color: #111827; }
    p { margin: 0 0 24px; color: #6B7280; font-size: 15px; line-height: 1.5; }
    .btn { display: inline-block; background: #10B981; color: white; padding: 12px 28px; border-radius: 12px; text-decoration: none; font-weight: 600; font-size: 15px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h2>Payment Successful!</h2>
    <p>Your payment has been received and confirmed. You can now return to WhatsApp.</p>
    <a href="https://web.whatsapp.com" class="btn">Back to WhatsApp</a>
  </div>
</body>
</html>`);
            } catch (err) {
                res.status(500).send('Error processing payment confirmation');
            }
        },
    };
}

module.exports = { createCatalogController };
