const mongoose = require('mongoose');

const whatsAppFlowResponseSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    flowId: { type: String, required: true, index: true },
    flowName: { type: String, default: '' },
    contactId: { type: String, required: true, index: true }, // customer phone
    contactName: { type: String, default: '' },
    wamid: { type: String, default: '', index: true },
    flowToken: { type: String, default: '' },
    responseData: { type: mongoose.Schema.Types.Mixed, default: {} },
    source: { type: String, default: 'chat', enum: ['chat', 'chatbot', 'campaign'] },
}, { timestamps: true });

whatsAppFlowResponseSchema.index({ tenantId: 1, createdAt: -1 });

module.exports = mongoose.model('WhatsAppFlowResponse', whatsAppFlowResponseSchema);
