const mongoose = require('mongoose');

const employeeSchema = new mongoose.Schema({
    tenantId: {
        type: String,
        required: true,
        index: true
    },
    name: {
        type: String,
        required: true,
        trim: true
    },
    email: {
        type: String,
        required: true,
        trim: true,
        lowercase: true,
        index: true
    },
    password: {
        type: String,
        required: true
    },
    role: {
        type: String,
        enum: ['employee', 'manager'],
        default: 'employee'
    },
    defaultCountry: {
        type: String,
        default: null,
        trim: true,
        uppercase: true
    },
    permissions: [{
        type: String,
        enum: [
            'chat',
            'broadcast',
            'templates',
            'clients',
            'leads',
            'reports',
            'chatbot',
            'catalog',
            'whatsapp_flows',
            'instagram',
            'help'
        ]
    }],
    status: {
        type: String,
        enum: ['active', 'inactive'],
        default: 'active'
    },
    createdBy: {
        type: String,
        default: null
    },
    lastLogin: {
        type: Date,
        default: null
    }
}, { timestamps: true });

employeeSchema.index({ tenantId: 1, email: 1 }, { unique: true });

const Employee = mongoose.model('Employee', employeeSchema);

module.exports = Employee;
