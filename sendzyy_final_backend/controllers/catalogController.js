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

                const { catalogId } = req.body;
                if (!catalogId) {
                    return res.status(400).json({ success: false, error: 'catalogId is required' });
                }

                const result = await CatalogService.selectCatalog(tenant, catalogId);
                res.json(result);
            } catch (err) {
                console.error('[CatalogController] selectCatalog error:', err);
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
                res.status(err.response?.status || 500).json({ success: false, error: err.message });
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
                res.status(err.response?.status || 500).json({ success: false, error: err.message });
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
                res.status(err.response?.status || 500).json({ success: false, error: err.message });
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
                res.status(err.response?.status || 500).json({ success: false, error: err.message });
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
                const payload = req.body?.payload;

                let orderId = null;
                let paymentId = null;

                if (payload?.payment_link?.entity?.notes?.orderId) {
                    orderId = payload.payment_link.entity.notes.orderId;
                    paymentId = payload?.payment?.entity?.id || payload.payment_link.entity.id;
                } else if (payload?.payment?.entity?.notes?.orderId) {
                    orderId = payload.payment.entity.notes.orderId;
                    paymentId = payload.payment.entity.id;
                }

                if (orderId) {
                    await CatalogService.handlePaymentSuccess(dependencies, {
                        orderId,
                        paymentId,
                    });
                }

                res.json({ status: 'ok' });
            } catch (err) {
                console.error('[CatalogController] handlePaymentWebhook error:', err);
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
