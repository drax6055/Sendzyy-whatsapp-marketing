const mongoose = require('mongoose');

const orderProductItemSchema = new mongoose.Schema({
    productRetailerId: { type: String, required: true },
    quantity: { type: Number, required: true },
    itemPrice: { type: Number, required: true },
    currency: { type: String, default: 'INR' },
    productName: { type: String, default: '' },      // Resolved from DB if possible
    imageUrl: { type: String, default: '' },
}, { _id: false });

const catalogOrderSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    catalogId: { type: String, required: true },
    customerPhone: { type: String, required: true },
    customerName: { type: String, default: '' },
    productItems: [orderProductItemSchema],
    orderText: { type: String, default: '' },       // Customer's note with the cart
    totalAmount: { type: Number, default: 0 },
    currency: { type: String, default: 'INR' },
    status: { type: String, default: 'new', enum: ['new', 'viewed', 'fulfilled', 'cancelled'] },
}, { timestamps: true });

catalogOrderSchema.index({ tenantId: 1, createdAt: -1 });

module.exports = mongoose.model('CatalogOrder', catalogOrderSchema);
