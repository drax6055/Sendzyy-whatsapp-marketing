const mongoose = require('mongoose');

const catalogProductSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    catalogId: { type: String, required: true, index: true },   // Meta catalog ID
    productId: { type: String, default: '' },                   // Meta product ID (after creation)
    retailerId: { type: String, required: true },               // Unique SKU / retailer ID
    name: { type: String, required: true },
    description: { type: String, default: '' },
    price: { type: Number, required: true },
    currency: { type: String, default: 'INR' },
    imageUrl: { type: String, default: '' },                    // Public S3 URL
    availability: { type: String, default: 'in stock', enum: ['in stock', 'out of stock', 'preorder', 'available for order', 'discontinued'] },
    condition: { type: String, default: 'new', enum: ['new', 'used', 'refurbished'] },
    link: { type: String, default: '' },
    brand: { type: String, default: '' },
    category: { type: String, default: '' },
    salePrice: { type: Number, default: null },
    isSynced: { type: Boolean, default: false },               // Whether pushed to Meta
    metaSyncedAt: { type: Date, default: null },
}, { timestamps: true });

catalogProductSchema.index({ tenantId: 1, catalogId: 1, retailerId: 1 }, { unique: true });

module.exports = mongoose.model('CatalogProduct', catalogProductSchema);
