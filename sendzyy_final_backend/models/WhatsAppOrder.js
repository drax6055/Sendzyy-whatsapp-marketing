const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
    productRetailerId: { type: String, required: true },
    quantity: { type: Number, required: true, default: 1 },
    itemPrice: { type: Number, default: 0 },
    currency: { type: String, default: 'INR' },
}, { _id: false });

const whatsAppOrderSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    contactId: { type: String, required: true, index: true }, // Customer WhatsApp phone
    contactName: { type: String, default: '' },
    catalogId: { type: String, default: '', index: true },
    wamid: { type: String, default: '', index: true },
    customerNote: { type: String, default: '' },
    items: [orderItemSchema],
    totalAmount: { type: Number, default: 0 },
    currency: { type: String, default: 'INR' },
    status: {
        type: String,
        enum: ['received', 'accepted', 'processing', 'completed', 'cancelled'],
        default: 'received',
        index: true,
    },
    paymentStatus: {
        type: String,
        enum: ['pending', 'paid', 'failed', 'refunded'],
        default: 'pending',
        index: true,
    },
    paymentLinkId: { type: String, default: null },
    paymentLinkUrl: { type: String, default: null },
    paymentId: { type: String, default: null },
    paidAt: { type: Date, default: null },
    rawOrderPayload: { type: mongoose.Schema.Types.Mixed, default: null },
}, { timestamps: true });

whatsAppOrderSchema.index({ tenantId: 1, createdAt: -1 });

module.exports = mongoose.model('WhatsAppOrder', whatsAppOrderSchema);
