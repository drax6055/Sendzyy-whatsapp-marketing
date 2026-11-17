const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    service: process.env.EMAIL_SERVICE || 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
    }
});

const MODULE_LABELS = {
    chat: '💬 Live Chat & Inbox',
    broadcast: '📢 Broadcast & Bulk Messaging',
    templates: '📋 WhatsApp Templates',
    clients: '👥 Contact / Client Management',
    leads: '🎯 Lead Management (IndiaMART, Meta Ads)',
    reports: '📊 Delivery & Campaign Reports',
    chatbot: '🤖 Chatbot Automation',
    catalog: '🛍️ Meta Commerce Catalog',
    whatsapp_flows: '📑 WhatsApp Interactive Flows',
    instagram: '📸 Instagram Automation & Chat',
    help: '❓ Q & A Support'
};

/**
 * Send automated welcome email with login credentials and module permissions to a new employee.
 *
 * @param {Object} options
 * @param {string} options.email - Employee's email
 * @param {string} options.name - Employee's name
 * @param {string} options.password - Plaintext password
 * @param {string} options.tenantName - Master Tenant organization name
 * @param {string[]} options.permissions - Granted module keys
 * @param {string} [options.loginUrl] - Optional panel URL
 */
async function sendEmployeeWelcomeEmail({ email, name, password, tenantName, permissions = [], loginUrl = null }) {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
        console.warn('[EmployeeMailService] Email credentials not configured in environment. Skipping email dispatch.');
        return { success: false, reason: 'missing_smtp_credentials' };
    }

    const panelUrl = loginUrl || process.env.FRONTEND_URL || 'https://app.sendzyy.com';

    const permissionChipsHtml = permissions.length > 0
        ? permissions.map(p => {
            const label = MODULE_LABELS[p] || p;
            return `<span style="display:inline-block;background:#E8F5E9;color:#2E7D32;padding:6px 14px;margin:4px 4px 4px 0;border-radius:20px;font-size:13px;font-weight:600;border:1px solid #C8E6C9;">${label}</span>`;
        }).join('')
        : '<span style="color:#757575;font-style:italic;">Default access assigned by administrator</span>';

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Sendzyy</title>
</head>
<body style="margin:0;padding:0;background-color:#F4F6F8;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F4F6F8;padding:40px 16px;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 10px 30px rgba(0,0,0,0.08);max-width:600px;width:100%;">
                    <!-- Header Banner -->
                    <tr>
                        <td style="background:linear-gradient(135deg, #1B5E20 0%, #2E7D32 50%, #43A047 100%);padding:40px 32px;text-align:center;">
                            <div style="background:rgba(255,255,255,0.2);display:inline-block;padding:12px 20px;border-radius:30px;margin-bottom:16px;">
                                <span style="font-size:24px;vertical-align:middle;">🚀</span>
                                <span style="color:#FFFFFF;font-size:18px;font-weight:700;letter-spacing:1px;vertical-align:middle;margin-left:8px;">SENDZYY</span>
                            </div>
                            <h1 style="color:#FFFFFF;margin:0 0 10px;font-size:26px;font-weight:700;">Welcome to the Team, ${name}!</h1>
                            <p style="color:#E8F5E9;margin:0;font-size:15px;line-height:1.5;">You have been invited by <strong>${tenantName}</strong> to collaborate on the Sendzyy WhatsApp Marketing platform.</p>
                        </td>
                    </tr>

                    <!-- Body Content -->
                    <tr>
                        <td style="padding:36px 32px;">
                            <p style="color:#37474F;font-size:15px;line-height:1.6;margin-top:0;">
                                Hello <strong>${name}</strong>,<br><br>
                                Your employee account has been created. You can now log into the Sendzyy dashboard with your personal credentials below. Your account automatically inherits your organization's official WhatsApp Business credentials under the hood.
                            </p>

                            <!-- Credentials Card -->
                            <div style="background:#F9FBF9;border:1px solid #E0E7E0;border-left:5px solid #2E7D32;border-radius:8px;padding:20px 24px;margin:24px 0;">
                                <h3 style="color:#1B5E20;margin:0 0 14px;font-size:16px;text-transform:uppercase;letter-spacing:0.8px;">🔐 Your Login Credentials</h3>
                                <table width="100%" cellpadding="4" cellspacing="0" style="font-size:14px;color:#263238;">
                                    <tr>
                                        <td width="110" style="color:#607D8B;font-weight:600;">Email Address:</td>
                                        <td style="font-family:monospace;font-weight:700;font-size:15px;color:#1B5E20;">${email}</td>
                                    </tr>
                                    <tr>
                                        <td style="color:#607D8B;font-weight:600;">Password:</td>
                                        <td style="font-family:monospace;font-weight:700;font-size:15px;color:#2E7D32;background:#E8F5E9;padding:4px 8px;border-radius:4px;display:inline-block;">${password}</td>
                                    </tr>
                                    <tr>
                                        <td style="color:#607D8B;font-weight:600;">Organization:</td>
                                        <td style="font-weight:600;color:#37474F;">${tenantName}</td>
                                    </tr>
                                </table>
                            </div>

                            <!-- Granted Modules -->
                            <div style="margin:24px 0;">
                                <h3 style="color:#37474F;margin:0 0 12px;font-size:15px;font-weight:700;">📦 Granted Module Permissions</h3>
                                <p style="color:#78909C;font-size:13px;margin:0 0 10px;">You have access to the following modules assigned by your administrator:</p>
                                <div>
                                    ${permissionChipsHtml}
                                </div>
                            </div>

                            <!-- CTA Button -->
                            <div style="text-align:center;margin:32px 0 20px;">
                                <a href="${panelUrl}" target="_blank" style="background:linear-gradient(135deg, #2E7D32 0%, #43A047 100%);color:#FFFFFF;text-decoration:none;padding:14px 36px;font-size:16px;font-weight:700;border-radius:8px;display:inline-block;box-shadow:0 4px 14px rgba(46,125,50,0.35);">
                                    Log In to Sendzyy Dashboard →
                                </a>
                            </div>

                            <p style="color:#90A4AE;font-size:12px;text-align:center;margin:16px 0 0;">
                                🔒 For security reasons, we strongly recommend changing your password upon your first login.
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="background-color:#ECEFF1;padding:20px 32px;text-align:center;border-top:1px solid #E0E0E0;">
                            <p style="color:#78909C;font-size:12px;margin:0;line-height:1.5;">
                                © ${new Date().getFullYear()} Sendzyy. All rights reserved.<br>
                                Automated notification sent on behalf of ${tenantName}.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`;

    try {
        const info = await transporter.sendMail({
            from: `"Sendzyy Team" <${process.env.EMAIL_USER}>`,
            to: email,
            subject: `🎉 Welcome to Sendzyy — Your Team Member Account is Ready!`,
            html
        });
        console.log(`[EmployeeMailService] Welcome email delivered successfully to ${email} (messageId: ${info.messageId})`);
        return { success: true, messageId: info.messageId };
    } catch (err) {
        console.error(`[EmployeeMailService] Failed to send welcome email to ${email}:`, err.message);
        return { success: false, error: err.message };
    }
}

module.exports = {
    sendEmployeeWelcomeEmail,
    MODULE_LABELS
};
