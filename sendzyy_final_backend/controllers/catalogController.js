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

                const catalogs = tenant.whatsappConfig?.catalogs || [];
                const activeCatalogId = tenant.whatsappConfig?.catalogId || (catalogs[0]?.catalogId || null);

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

                const orders = await WhatsAppOrder.find(query).sort({ createdAt: -1 }).limit(limit).lean();
                res.json({ success: true, orders, count: orders.length });
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
    };
}

module.exports = { createCatalogController };
