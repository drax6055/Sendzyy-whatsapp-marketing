const mongoose = require('mongoose');

const catalogSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    catalogId: { type: String, required: true },          // Meta catalog ID
    catalogName: { type: String, required: true },
    description: { type: String, default: '' },
    linkedToWabaId: { type: String, default: '' },        // WABA ID it's linked to
    isLinked: { type: Boolean, default: false },
    verticalType: { type: String, default: 'commerce' },  // Meta catalog vertical
    productCount: { type: Number, default: 0 },
}, { timestamps: true });

catalogSchema.index({ tenantId: 1, catalogId: 1 }, { unique: true });

module.exports = mongoose.model('Catalog', catalogSchema);
