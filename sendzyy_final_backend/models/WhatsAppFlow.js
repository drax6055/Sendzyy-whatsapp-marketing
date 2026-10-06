const mongoose = require('mongoose');

const whatsAppFlowSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    flowId: { type: String, required: true, index: true }, // Meta Flow ID
    name: { type: String, required: true },
    categories: { type: [String], default: ['LEAD_GENERATION'] },
    status: { type: String, default: 'DRAFT', enum: ['DRAFT', 'PUBLISHED', 'DEPRECATED', 'BLOCKED'] },
    flowJson: { type: mongoose.Schema.Types.Mixed, default: {} },
    fieldsConfig: { type: [mongoose.Schema.Types.Mixed], default: [] }, // Visual builder fields
    ctaText: { type: String, default: 'Open Form' },
    headerText: { type: String, default: '' },
    bodyText: { type: String, default: '' },
    footerText: { type: String, default: 'Powered by Sendzyy' },
    validationErrors: { type: [mongoose.Schema.Types.Mixed], default: [] },
    metaLastSyncedAt: { type: Date, default: Date.now }
}, { timestamps: true });

whatsAppFlowSchema.index({ tenantId: 1, flowId: 1 }, { unique: true });

module.exports = mongoose.model('WhatsAppFlow', whatsAppFlowSchema);
