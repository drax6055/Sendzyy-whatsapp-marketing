const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const Employee = require('../models/Employee');
const { sendEmployeeWelcomeEmail } = require('../services/EmployeeMailService');

/**
 * Middleware: Ensure requester is a Master Tenant Super-Admin (not an employee).
 */
const requireAdmin = (req, res, next) => {
    if (!req.user || !req.user.tenantId) {
        return res.status(401).json({ error: 'unauthorized', message: 'Authentication required' });
    }
    if (req.user.role === 'employee') {
        return res.status(403).json({
            error: 'forbidden',
            message: 'Access restricted: Only Master Tenant Administrators can manage team members.'
        });
    }
    next();
};

/**
 * GET /api/employees
 * List all employees for the authenticated tenant with workload stats (assigned conversations count).
 */
router.get('/', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const employees = await Employee.find({ tenantId })
            .select('-password')
            .sort({ createdAt: -1 })
            .lean();

        // Get mongoose Conversation model
        const mongoose = require('mongoose');
        const Conversation = mongoose.model('Conversation');

        // Aggregate conversation counts per employee
        const convCounts = await Conversation.aggregate([
            { $match: { tenantId, assignedTo: { $ne: null } } },
            { $group: { _id: '$assignedTo', count: { $sum: 1 } } }
        ]);

        const countMap = {};
        for (const item of convCounts) {
            if (item._id) countMap[item._id.toString()] = item.count;
        }

        const enrichedEmployees = employees.map(emp => ({
            ...emp,
            id: emp._id.toString(),
            assignedChatsCount: countMap[emp._id.toString()] || 0
        }));

        res.json({
            success: true,
            employees: enrichedEmployees
        });
    } catch (err) {
        console.error('[EmployeeRoutes] GET / error:', err);
        res.status(500).json({ error: 'Failed to retrieve team members', details: err.message });
    }
});

/**
 * POST /api/employees
 * Master Tenant Super-Admin creates a new employee.
 * Generates password hash, saves employee, dispatches automated welcome email.
 */
router.post('/', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const { name, email, password, permissions = [], role = 'employee' } = req.body;

        if (!name || !name.trim()) {
            return res.status(400).json({ error: 'Employee name is required' });
        }
        if (!email || !email.trim()) {
            return res.status(400).json({ error: 'Employee email is required' });
        }
        if (!password || password.length < 6) {
            return res.status(400).json({ error: 'Password is required and must be at least 6 characters long' });
        }

        const normalizedEmail = email.trim().toLowerCase();

        // Check if email already exists in Tenant collection
        const mongoose = require('mongoose');
        const Tenant = mongoose.model('Tenant');
        const existingTenant = await Tenant.findOne({ email: normalizedEmail });
        if (existingTenant) {
            return res.status(400).json({ error: 'An organization account already exists with this email address.' });
        }

        // Check if employee with same email already exists under this tenant
        const existingEmployee = await Employee.findOne({ tenantId, email: normalizedEmail });
        if (existingEmployee) {
            return res.status(400).json({ error: 'A team member with this email already exists in your organization.' });
        }

        // Fetch parent tenant to display organization name in email
        const parentTenant = await Tenant.findById(tenantId);
        const tenantName = parentTenant ? parentTenant.name : 'Your Organization';

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Sanitize permissions array
        const allowedPermissions = [
            'chat', 'broadcast', 'templates', 'clients', 'leads',
            'reports', 'chatbot', 'catalog', 'whatsapp_flows', 'instagram', 'help'
        ];
        const validPermissions = Array.isArray(permissions)
            ? permissions.filter(p => allowedPermissions.includes(p))
            : [];
        // Reports is compulsory and permanent for every employee
        if (!validPermissions.includes('reports')) {
            validPermissions.push('reports');
        }

        const newEmployee = new Employee({
            tenantId,
            name: name.trim(),
            email: normalizedEmail,
            password: hashedPassword,
            role: role === 'manager' ? 'manager' : 'employee',
            permissions: validPermissions,
            status: 'active',
            createdBy: req.user.tenantId
        });

        await newEmployee.save();

        // Dispatch automated welcome email in background
        sendEmployeeWelcomeEmail({
            email: normalizedEmail,
            name: newEmployee.name,
            password,
            tenantName,
            permissions: validPermissions
        }).catch(mailErr => {
            console.error('[EmployeeRoutes] Background welcome email error:', mailErr.message);
        });

        const employeeObj = newEmployee.toObject();
        delete employeeObj.password;
        employeeObj.id = employeeObj._id.toString();
        employeeObj.assignedChatsCount = 0;

        res.status(201).json({
            success: true,
            message: 'Team member account created successfully. Welcome email dispatched.',
            employee: employeeObj
        });
    } catch (err) {
        console.error('[EmployeeRoutes] POST / error:', err);
        res.status(500).json({ error: 'Failed to create team member', details: err.message });
    }
});

/**
 * GET /api/employees/me/profile
 * Retrieve authenticated employee's own profile and workload stats.
 */
router.get('/me/profile', async (req, res) => {
    try {
        if (req.user.role !== 'employee' || !req.user.employeeId) {
            return res.status(400).json({ error: 'not_employee', message: 'This endpoint is for employee accounts.' });
        }

        const employee = await Employee.findOne({ _id: req.user.employeeId, tenantId: req.user.tenantId })
            .select('-password')
            .lean();

        if (!employee) {
            return res.status(404).json({ error: 'Employee not found' });
        }

        const mongoose = require('mongoose');
        const Tenant = mongoose.model('Tenant');
        const Conversation = mongoose.model('Conversation');

        const [tenant, assignedChatsCount] = await Promise.all([
            Tenant.findById(req.user.tenantId).select('name email defaultCountry').lean(),
            Conversation.countDocuments({ tenantId: req.user.tenantId, assignedTo: employee._id.toString() })
        ]);

        // Guarantee reports is included
        const perms = employee.permissions || [];
        if (!perms.includes('reports')) perms.push('reports');

        res.json({
            success: true,
            employee: {
                ...employee,
                id: employee._id.toString(),
                permissions: perms,
                tenantName: tenant ? tenant.name : 'Your Organization',
                defaultCountry: employee.defaultCountry || tenant?.defaultCountry || 'IN',
                assignedChatsCount
            }
        });
    } catch (err) {
        console.error('[EmployeeRoutes] GET /me/profile error:', err);
        res.status(500).json({ error: 'Failed to fetch employee profile', details: err.message });
    }
});

/**
 * PUT /api/employees/me/profile
 * Update authenticated employee's display name and/or password.
 */
router.put('/me/profile', async (req, res) => {
    try {
        if (req.user.role !== 'employee' || !req.user.employeeId) {
            return res.status(400).json({ error: 'not_employee', message: 'This endpoint is for employee accounts.' });
        }

        const { name, currentPassword, newPassword, defaultCountry } = req.body;
        const employee = await Employee.findOne({ _id: req.user.employeeId, tenantId: req.user.tenantId });
        if (!employee) {
            return res.status(404).json({ error: 'Employee not found' });
        }

        // Default Country update
        if (defaultCountry && typeof defaultCountry === 'string') {
            const code = defaultCountry.trim().toUpperCase();
            if (/^[A-Z]{2,3}$/.test(code)) {
                employee.defaultCountry = code;
            }
        }

        // Name update
        if (name && name.trim()) {
            employee.name = name.trim();
            // Update assignedToName across employee's active conversations
            const mongoose = require('mongoose');
            const Conversation = mongoose.model('Conversation');
            await Conversation.updateMany(
                { tenantId: req.user.tenantId, assignedTo: employee._id.toString() },
                { $set: { assignedToName: employee.name } }
            );
        }

        // Password update
        if (newPassword) {
            if (!currentPassword) {
                return res.status(400).json({ error: 'Current password is required to change your password.' });
            }
            const isMatch = await bcrypt.compare(currentPassword, employee.password);
            if (!isMatch) {
                return res.status(400).json({ error: 'Incorrect current password.' });
            }
            if (newPassword.length < 6) {
                return res.status(400).json({ error: 'New password must be at least 6 characters long.' });
            }
            employee.password = await bcrypt.hash(newPassword, 10);
        }

        await employee.save();

        const employeeObj = employee.toObject();
        delete employeeObj.password;
        employeeObj.id = employeeObj._id.toString();

        res.json({
            success: true,
            message: 'Profile updated successfully',
            employee: employeeObj
        });
    } catch (err) {
        console.error('[EmployeeRoutes] PUT /me/profile error:', err);
        res.status(500).json({ error: 'Failed to update profile', details: err.message });
    }
});

/**
 * GET /api/employees/reports/analytics
 * Comprehensive report and performance analytics for all employees under the Master Tenant.
 * Supports date filtering (?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD), search, and status filter.
 */
router.get('/reports/analytics', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const { startDate, endDate, search, status } = req.query;

        // Base query for employees
        const empQuery = { tenantId };
        if (status && ['active', 'inactive'].includes(status)) {
            empQuery.status = status;
        }
        if (search && search.trim()) {
            const regex = new RegExp(search.trim(), 'i');
            empQuery.$or = [{ name: regex }, { email: regex }];
        }

        const employees = await Employee.find(empQuery)
            .select('-password')
            .sort({ createdAt: -1 })
            .lean();

        const mongoose = require('mongoose');
        const Campaign = mongoose.model('Campaign');
        const Conversation = mongoose.model('Conversation');
        const Message = mongoose.model('Message');

        // Build campaign date filter
        const campaignFilter = { tenantId };
        if (startDate || endDate) {
            campaignFilter.timestamp = {};
            if (startDate) {
                const s = new Date(startDate);
                if (!isNaN(s)) campaignFilter.timestamp.$gte = s;
            }
            if (endDate) {
                const e = new Date(endDate);
                if (!isNaN(e)) {
                    e.setHours(23, 59, 59, 999);
                    campaignFilter.timestamp.$lte = e;
                }
            }
        }

        // Fetch all campaigns in tenant within date range
        const allCampaigns = await Campaign.find(campaignFilter)
            .sort({ timestamp: -1 })
            .lean();

        // Group campaigns by createdBy (employee id)
        const campaignsByEmployee = {};
        for (const camp of allCampaigns) {
            const creator = (camp.createdBy || 'admin').toString();
            if (!campaignsByEmployee[creator]) {
                campaignsByEmployee[creator] = [];
            }
            campaignsByEmployee[creator].push(camp);
        }

        // Conversation count per employee
        const convCounts = await Conversation.aggregate([
            { $match: { tenantId, assignedTo: { $ne: null } } },
            { $group: { _id: '$assignedTo', count: { $sum: 1 } } }
        ]);
        const convCountMap = {};
        for (const item of convCounts) {
            if (item._id) convCountMap[item._id.toString()] = item.count;
        }

        // Message count per employee (outbound messages sent by employees)
        const messageFilter = { tenantId, senderId: { $ne: null }, isMe: true };
        if (startDate || endDate) {
            messageFilter.timestamp = {};
            if (startDate) {
                const s = new Date(startDate);
                if (!isNaN(s)) messageFilter.timestamp.$gte = s;
            }
            if (endDate) {
                const e = new Date(endDate);
                if (!isNaN(e)) {
                    e.setHours(23, 59, 59, 999);
                    messageFilter.timestamp.$lte = e;
                }
            }
        }
        const messageCounts = await Message.aggregate([
            { $match: messageFilter },
            { $group: { _id: '$senderId', count: { $sum: 1 } } }
        ]);
        const messageCountMap = {};
        for (const item of messageCounts) {
            if (item._id) messageCountMap[item._id.toString()] = item.count;
        }

        // Fetch recent assigned conversations for quick preview
        const recentConvs = await Conversation.find({ tenantId, assignedTo: { $ne: null } })
            .sort({ lastActive: -1 })
            .limit(100)
            .lean();
        const convsByEmployee = {};
        for (const c of recentConvs) {
            const assignee = c.assignedTo ? c.assignedTo.toString() : null;
            if (assignee) {
                if (!convsByEmployee[assignee]) convsByEmployee[assignee] = [];
                convsByEmployee[assignee].push({
                    id: c._id.toString(),
                    contactId: c.contactId,
                    name: c.name || c.contactId,
                    lastMessage: c.lastMessage || '',
                    lastActive: c.lastActive,
                    hasReply: c.hasReply || false
                });
            }
        }

        // Aggregate summary metrics across all employees
        let totalCampaignsByTeam = 0;
        let totalSentByTeam = 0;
        let totalDeliveredByTeam = 0;
        let totalReadByTeam = 0;
        let totalFailedByTeam = 0;
        let totalAssignedChatsByTeam = 0;
        let totalChatMessagesSentByTeam = 0;

        const employeeReports = employees.map(emp => {
            const empId = emp._id.toString();
            const empCampaigns = campaignsByEmployee[empId] || [];

            let totalSent = 0;
            let totalDelivered = 0;
            let totalRead = 0;
            let totalFailed = 0;

            for (const c of empCampaigns) {
                const sent = (c.totalCount || c.successCount || 0);
                const delivered = (c.deliveredCount || 0);
                const read = (c.readCount || 0);
                const failed = (c.failureCount || 0);

                totalSent += sent;
                totalDelivered += delivered;
                totalRead += read;
                totalFailed += failed;
            }

            const deliveryRate = totalSent > 0 ? parseFloat(((totalDelivered / totalSent) * 100).toFixed(1)) : 0;
            const readRate = totalDelivered > 0 ? parseFloat(((totalRead / totalDelivered) * 100).toFixed(1)) : 0;
            const assignedChatsCount = convCountMap[empId] || 0;
            const chatMessagesSentCount = messageCountMap[empId] || 0;

            totalCampaignsByTeam += empCampaigns.length;
            totalSentByTeam += totalSent;
            totalDeliveredByTeam += totalDelivered;
            totalReadByTeam += totalRead;
            totalFailedByTeam += totalFailed;
            totalAssignedChatsByTeam += assignedChatsCount;
            totalChatMessagesSentByTeam += chatMessagesSentCount;

            return {
                id: empId,
                name: emp.name,
                email: emp.email,
                role: emp.role || 'employee',
                status: emp.status || 'active',
                permissions: emp.permissions || [],
                createdAt: emp.createdAt,
                lastLogin: emp.lastLogin,
                stats: {
                    campaignsCount: empCampaigns.length,
                    totalSent,
                    totalDelivered,
                    totalRead,
                    totalFailed,
                    deliveryRate,
                    readRate,
                    assignedChatsCount,
                    chatMessagesSentCount
                },
                recentCampaigns: empCampaigns.slice(0, 10).map(c => ({
                    id: c.id,
                    template: c.template,
                    timestamp: c.timestamp || c.createdAt,
                    totalCount: c.totalCount || c.successCount || 0,
                    deliveredCount: c.deliveredCount || 0,
                    readCount: c.readCount || 0,
                    failureCount: c.failureCount || 0,
                    status: c.status || 'completed'
                })),
                recentConversations: (convsByEmployee[empId] || []).slice(0, 5)
            };
        });

        const overallDeliveryRate = totalSentByTeam > 0
            ? parseFloat(((totalDeliveredByTeam / totalSentByTeam) * 100).toFixed(1))
            : 0;
        const overallReadRate = totalDeliveredByTeam > 0
            ? parseFloat(((totalReadByTeam / totalDeliveredByTeam) * 100).toFixed(1))
            : 0;

        res.json({
            success: true,
            summary: {
                totalEmployees: employees.length,
                activeEmployees: employees.filter(e => e.status === 'active').length,
                inactiveEmployees: employees.filter(e => e.status === 'inactive').length,
                totalCampaignsByTeam,
                totalSentByTeam,
                totalDeliveredByTeam,
                totalReadByTeam,
                totalFailedByTeam,
                overallDeliveryRate,
                overallReadRate,
                totalAssignedChatsByTeam,
                totalChatMessagesSentByTeam
            },
            employees: employeeReports
        });
    } catch (err) {
        console.error('[EmployeeRoutes] GET /reports/analytics error:', err);
        res.status(500).json({ error: 'Failed to generate employee analytics report', details: err.message });
    }
});

/**
 * GET /api/employees/:id/report
 * Detailed full report for a specific employee: complete campaigns history, complete assigned chats, message activity.
 */
router.get('/:id/report', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const employeeId = req.params.id;

        const employee = await Employee.findOne({ _id: employeeId, tenantId })
            .select('-password')
            .lean();

        if (!employee) {
            return res.status(404).json({ error: 'Employee not found' });
        }

        const mongoose = require('mongoose');
        const Campaign = mongoose.model('Campaign');
        const Conversation = mongoose.model('Conversation');
        const Message = mongoose.model('Message');

        const { startDate, endDate } = req.query;
        const dateFilter = {};
        if (startDate || endDate) {
            dateFilter.timestamp = {};
            if (startDate) {
                const s = new Date(startDate);
                if (!isNaN(s)) dateFilter.timestamp.$gte = s;
            }
            if (endDate) {
                const e = new Date(endDate);
                if (!isNaN(e)) {
                    e.setHours(23, 59, 59, 999);
                    dateFilter.timestamp.$lte = e;
                }
            }
        }

        // All campaigns created by this employee
        const campaigns = await Campaign.find({
            tenantId,
            createdBy: employeeId,
            ...dateFilter
        }).sort({ timestamp: -1 }).lean();

        let totalSent = 0;
        let totalDelivered = 0;
        let totalRead = 0;
        let totalFailed = 0;

        for (const c of campaigns) {
            totalSent += (c.totalCount || c.successCount || 0);
            totalDelivered += (c.deliveredCount || 0);
            totalRead += (c.readCount || 0);
            totalFailed += (c.failureCount || 0);
        }

        // Assigned conversations
        const conversations = await Conversation.find({
            tenantId,
            assignedTo: employeeId
        }).sort({ lastActive: -1 }).lean();

        // Chat messages sent
        const chatMessagesCount = await Message.countDocuments({
            tenantId,
            senderId: employeeId,
            isMe: true,
            ...dateFilter
        });

        const deliveryRate = totalSent > 0 ? parseFloat(((totalDelivered / totalSent) * 100).toFixed(1)) : 0;
        const readRate = totalDelivered > 0 ? parseFloat(((totalRead / totalDelivered) * 100).toFixed(1)) : 0;

        res.json({
            success: true,
            employee: {
                ...employee,
                id: employee._id.toString()
            },
            stats: {
                campaignsCount: campaigns.length,
                totalSent,
                totalDelivered,
                totalRead,
                totalFailed,
                deliveryRate,
                readRate,
                assignedChatsCount: conversations.length,
                chatMessagesSentCount: chatMessagesCount
            },
            campaigns: campaigns.map(c => ({
                id: c.id,
                template: c.template,
                timestamp: c.timestamp || c.createdAt,
                totalCount: c.totalCount || c.successCount || 0,
                deliveredCount: c.deliveredCount || 0,
                readCount: c.readCount || 0,
                failureCount: c.failureCount || 0,
                status: c.status || 'completed',
                hasPendingRetry: c.status === 'retrying'
            })),
            conversations: conversations.map(c => ({
                id: c._id.toString(),
                contactId: c.contactId,
                name: c.name || c.contactId,
                lastMessage: c.lastMessage || '',
                lastActive: c.lastActive,
                hasReply: c.hasReply || false,
                assignedAt: c.assignedAt
            }))
        });
    } catch (err) {
        console.error('[EmployeeRoutes] GET /:id/report error:', err);
        res.status(500).json({ error: 'Failed to fetch detailed employee report', details: err.message });
    }
});

/**
 * GET /api/employees/:id
 * Retrieve single employee details.
 */
router.get('/:id', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const employee = await Employee.findOne({ _id: req.params.id, tenantId })
            .select('-password')
            .lean();

        if (!employee) {
            return res.status(404).json({ error: 'Team member not found' });
        }

        const mongoose = require('mongoose');
        const Conversation = mongoose.model('Conversation');
        const chatCount = await Conversation.countDocuments({ tenantId, assignedTo: employee._id.toString() });

        res.json({
            success: true,
            employee: {
                ...employee,
                id: employee._id.toString(),
                assignedChatsCount: chatCount
            }
        });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch team member', details: err.message });
    }
});

/**
 * PUT /api/employees/:id
 * Update employee profile, permissions, status, or reset password.
 */
router.put('/:id', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const { name, email, permissions, status, password, role } = req.body;

        const employee = await Employee.findOne({ _id: req.params.id, tenantId });
        if (!employee) {
            return res.status(404).json({ error: 'Team member not found' });
        }

        if (name && name.trim()) employee.name = name.trim();
        if (email && email.trim()) {
            const normalizedEmail = email.trim().toLowerCase();
            if (normalizedEmail !== employee.email) {
                const existing = await Employee.findOne({ tenantId, email: normalizedEmail, _id: { $ne: employee._id } });
                if (existing) {
                    return res.status(400).json({ error: 'Another team member already uses this email address.' });
                }
                employee.email = normalizedEmail;
            }
        }

        if (Array.isArray(permissions)) {
            const allowedPermissions = [
                'chat', 'broadcast', 'templates', 'clients', 'leads',
                'reports', 'chatbot', 'catalog', 'whatsapp_flows', 'instagram', 'help'
            ];
            const updatedPerms = permissions.filter(p => allowedPermissions.includes(p));
            if (!updatedPerms.includes('reports')) {
                updatedPerms.push('reports');
            }
            employee.permissions = updatedPerms;
        }

        if (status && ['active', 'inactive'].includes(status)) {
            employee.status = status;
        }

        if (role && ['employee', 'manager'].includes(role)) {
            employee.role = role;
        }

        if (password && password.length >= 6) {
            employee.password = await bcrypt.hash(password, 10);
        }

        await employee.save();

        const employeeObj = employee.toObject();
        delete employeeObj.password;
        employeeObj.id = employeeObj._id.toString();

        res.json({
            success: true,
            message: 'Team member updated successfully',
            employee: employeeObj
        });
    } catch (err) {
        console.error('[EmployeeRoutes] PUT /:id error:', err);
        res.status(500).json({ error: 'Failed to update team member', details: err.message });
    }
});

/**
 * PATCH /api/employees/:id/status
 * Quick toggle status ('active' / 'inactive').
 */
router.patch('/:id/status', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const { status } = req.body;
        if (!['active', 'inactive'].includes(status)) {
            return res.status(400).json({ error: 'Invalid status. Must be active or inactive.' });
        }

        const employee = await Employee.findOneAndUpdate(
            { _id: req.params.id, tenantId },
            { $set: { status } },
            { new: true }
        ).select('-password');

        if (!employee) return res.status(404).json({ error: 'Team member not found' });

        res.json({
            success: true,
            message: `Team member status set to ${status}`,
            employee: {
                ...employee.toObject(),
                id: employee._id.toString()
            }
        });
    } catch (err) {
        res.status(500).json({ error: 'Failed to update status', details: err.message });
    }
});

/**
 * DELETE /api/employees/:id
 * Delete team member and release/unassign their bound conversations.
 */
router.delete('/:id', requireAdmin, async (req, res) => {
    try {
        const tenantId = req.user.tenantId;
        const employeeId = req.params.id;

        const employee = await Employee.findOneAndDelete({ _id: employeeId, tenantId });
        if (!employee) {
            return res.status(404).json({ error: 'Team member not found' });
        }

        // Release/unassign conversations bound to this employee
        const mongoose = require('mongoose');
        const Conversation = mongoose.model('Conversation');
        const result = await Conversation.updateMany(
            { tenantId, assignedTo: employeeId },
            {
                $set: {
                    assignedTo: null,
                    assignedToName: null,
                    assignedAt: null,
                    assignedBy: null
                }
            }
        );

        console.log(`[EmployeeRoutes] Removed employee ${employee.name} (${employeeId}). Released ${result.modifiedCount} conversations.`);

        res.json({
            success: true,
            message: `Team member ${employee.name} removed. Released ${result.modifiedCount} assigned chat(s).`
        });
    } catch (err) {
        console.error('[EmployeeRoutes] DELETE /:id error:', err);
        res.status(500).json({ error: 'Failed to remove team member', details: err.message });
    }
});

module.exports = router;
