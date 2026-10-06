const axios = require('axios');
const FormData = require('form-data');
const WhatsAppFlow = require('../models/WhatsAppFlow');
const WhatsAppFlowResponse = require('../models/WhatsAppFlowResponse');

const GRAPH_API_VERSION = 'v22.0';
const GRAPH_BASE_URL = `https://graph.facebook.com/${GRAPH_API_VERSION}`;

/**
 * Compiles a visual list of form fields into Meta WhatsApp Flow JSON specification (v6.0)
 */
function compileFieldsToFlowJson({ title = 'Quick Form', description = '', fields = [], submitText = 'Submit' }) {
    const screenId = 'QUESTION_SCREEN';
    const formChildren = [];

    // Optional heading/subheading
    if (description) {
        formChildren.push({
            type: 'TextSubheading',
            text: description
        });
    }

    const payloadMap = {};

    fields.forEach((field, index) => {
        const fieldName = (field.name || `field_${index + 1}`).toLowerCase().replace(/[^a-z0-9_]/g, '_');
        payloadMap[fieldName] = `\${form.${fieldName}}`;

        switch (field.type) {
            case 'text':
            case 'short_text':
                formChildren.push({
                    type: 'TextInput',
                    name: fieldName,
                    label: field.label || 'Text',
                    required: field.required !== false,
                    'input-type': 'text'
                });
                break;

            case 'email':
                formChildren.push({
                    type: 'TextInput',
                    name: fieldName,
                    label: field.label || 'Email Address',
                    required: field.required !== false,
                    'input-type': 'email'
                });
                break;

            case 'phone':
            case 'number':
                formChildren.push({
                    type: 'TextInput',
                    name: fieldName,
                    label: field.label || 'Phone Number',
                    required: field.required !== false,
                    'input-type': 'number'
                });
                break;

            case 'textarea':
            case 'multiline':
                formChildren.push({
                    type: 'TextArea',
                    name: fieldName,
                    label: field.label || 'Details / Notes',
                    required: field.required === true
                });
                break;

            case 'dropdown':
            case 'select': {
                const options = (field.options || []).map((opt, i) => {
                    if (typeof opt === 'string') {
                        return { id: `opt_${i + 1}`, title: opt };
                    }
                    return { id: opt.id || `opt_${i + 1}`, title: opt.label || opt.title || `Option ${i + 1}` };
                });

                formChildren.push({
                    type: 'Dropdown',
                    name: fieldName,
                    label: field.label || 'Select Option',
                    required: field.required !== false,
                    'data-source': options
                });
                break;
            }

            case 'radio':
            case 'single_choice': {
                const options = (field.options || []).map((opt, i) => {
                    if (typeof opt === 'string') {
                        return { id: `opt_${i + 1}`, title: opt };
                    }
                    return { id: opt.id || `opt_${i + 1}`, title: opt.label || opt.title || `Option ${i + 1}` };
                });

                formChildren.push({
                    type: 'RadioButtonsGroup',
                    name: fieldName,
                    label: field.label || 'Choose one',
                    required: field.required !== false,
                    'data-source': options
                });
                break;
            }

            case 'checkbox':
            case 'multi_choice': {
                const options = (field.options || []).map((opt, i) => {
                    if (typeof opt === 'string') {
                        return { id: `opt_${i + 1}`, title: opt };
                    }
                    return { id: opt.id || `opt_${i + 1}`, title: opt.label || opt.title || `Option ${i + 1}` };
                });

                formChildren.push({
                    type: 'CheckboxGroup',
                    name: fieldName,
                    label: field.label || 'Choose options',
                    required: field.required === true,
                    'data-source': options
                });
                break;
            }

            case 'date':
                formChildren.push({
                    type: 'DatePicker',
                    name: fieldName,
                    label: field.label || 'Select Date',
                    required: field.required !== false
                });
                break;

            case 'opt_in':
                formChildren.push({
                    type: 'OptIn',
                    name: fieldName,
                    label: field.label || 'I agree to the terms',
                    required: field.required === true
                });
                break;

            default:
                formChildren.push({
                    type: 'TextInput',
                    name: fieldName,
                    label: field.label || 'Input',
                    required: false,
                    'input-type': 'text'
                });
                break;
        }
    });

    // Add submit footer
    formChildren.push({
        type: 'Footer',
        label: submitText,
        'on-click-action': {
            name: 'complete',
            payload: payloadMap
        }
    });

    return {
        version: '3.1',
        screens: [
            {
                id: screenId,
                title: title,
                terminal: true,
                success: true,
                data: {},
                layout: {
                    type: 'SingleColumnLayout',
                    children: [
                        {
                            type: 'Form',
                            name: 'flow_form',
                            children: formChildren
                        }
                    ]
                }
            }
        ],
        routing_model: {
            [screenId]: []
        }
    };
}

class WhatsAppFlowService {
    /**
     * Sync flows from Meta WABA for a tenant
     */
    static async syncFlowsFromMeta(tenant) {
        const config = tenant.whatsappConfig || {};
        const wabaId = config.businessAccountId;
        const accessToken = config.accessToken;

        if (!wabaId || !accessToken) {
            throw new Error('WhatsApp Business Account ID or Access Token is missing');
        }

        const url = `${GRAPH_BASE_URL}/${wabaId}/flows`;
        const res = await axios.get(url, {
            headers: { Authorization: `Bearer ${accessToken}` },
            params: { fields: 'id,name,status,categories,validation_errors' }
        });

        const metaFlows = res.data?.data || [];
        const syncedFlows = [];

        for (const mf of metaFlows) {
            let flowJson = null;
            try {
                const assetRes = await axios.get(`${GRAPH_BASE_URL}/${mf.id}/assets`, {
                    headers: { Authorization: `Bearer ${accessToken}` }
                });
                const flowJsonAsset = assetRes.data?.data?.find(a => a.asset_type === 'FLOW_JSON');
                if (flowJsonAsset?.download_url) {
                    const jsonRes = await axios.get(flowJsonAsset.download_url);
                    flowJson = jsonRes.data;
                }
            } catch (_) {}

            const updateFields = {
                tenantId: tenant._id.toString(),
                flowId: mf.id,
                name: mf.name || 'Untitled Flow',
                status: mf.status || 'DRAFT',
                categories: mf.categories || ['LEAD_GENERATION'],
                validationErrors: mf.validation_errors || [],
                metaLastSyncedAt: new Date()
            };
            if (flowJson) {
                updateFields.flowJson = flowJson;
            }

            const flowDoc = await WhatsAppFlow.findOneAndUpdate(
                { tenantId: tenant._id.toString(), flowId: mf.id },
                updateFields,
                { upsert: true, new: true }
            );
            syncedFlows.push(flowDoc);
        }

        return syncedFlows;
    }

    /**
     * Create, upload schema asset, and publish a new Flow on Meta
     */
    static async createAndPublishFlow(tenant, params) {
        const config = tenant.whatsappConfig || {};
        const wabaId = config.businessAccountId;
        const accessToken = config.accessToken;

        if (!wabaId || !accessToken) {
            throw new Error('WhatsApp Business Account ID or Access Token is missing');
        }

        const {
            name,
            categories = ['LEAD_GENERATION'],
            fieldsConfig = [],
            flowJson: customFlowJson,
            ctaText = 'Open Form',
            headerText = '',
            bodyText = '',
            footerText = 'Powered by Sendzyy',
            autoPublish = true
        } = params;

        // 1. Compile flowJson if visual fieldsConfig is given
        let finalFlowJson = customFlowJson;
        if (!finalFlowJson || Object.keys(finalFlowJson).length === 0) {
            finalFlowJson = compileFieldsToFlowJson({
                title: name,
                description: bodyText,
                fields: fieldsConfig,
                submitText: 'Submit'
            });
        }

        // 2. Step 1: Create Flow on Meta
        console.log(`[WhatsAppFlow] Creating Flow "${name}" on Meta WABA ${wabaId}...`);
        const createFlowUrl = `${GRAPH_BASE_URL}/${wabaId}/flows`;
        const createRes = await axios.post(
            createFlowUrl,
            { name, categories },
            { headers: { Authorization: `Bearer ${accessToken}` } }
        );

        const flowId = createRes.data?.id;
        if (!flowId) {
            throw new Error('Failed to obtain Flow ID from Meta');
        }
        console.log(`[WhatsAppFlow] Flow created with ID ${flowId}. Uploading JSON schema asset...`);

        // 3. Step 2: Upload Flow JSON Asset via multipart/form-data
        const jsonBuffer = Buffer.from(JSON.stringify(finalFlowJson, null, 2), 'utf-8');
        const form = new FormData();
        form.append('name', 'flow.json');
        form.append('asset_type', 'FLOW_JSON');
        form.append('file', jsonBuffer, {
            filename: 'flow.json',
            contentType: 'application/json'
        });

        const uploadAssetUrl = `${GRAPH_BASE_URL}/${flowId}/assets`;
        await axios.post(uploadAssetUrl, form, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
                ...form.getHeaders()
            }
        });
        console.log(`[WhatsAppFlow] Asset uploaded successfully for Flow ${flowId}`);

        // 4. Step 3: Publish Flow if requested
        let status = 'DRAFT';
        let validationErrors = [];

        if (autoPublish) {
            try {
                console.log(`[WhatsAppFlow] Publishing Flow ${flowId}...`);
                const publishUrl = `${GRAPH_BASE_URL}/${flowId}/publish`;
                const pubRes = await axios.post(
                    publishUrl,
                    {},
                    { headers: { Authorization: `Bearer ${accessToken}` } }
                );
                if (pubRes.data?.success) {
                    status = 'PUBLISHED';
                    console.log(`[WhatsAppFlow] Flow ${flowId} successfully published!`);
                }
            } catch (pubErr) {
                console.warn(`[WhatsAppFlow] Publish warning for Flow ${flowId}:`, pubErr.response?.data || pubErr.message);
                status = 'DRAFT';
                validationErrors = pubErr.response?.data?.error?.error_user_msg || [pubErr.message];
            }
        }

        // 5. Save in local database
        const savedDoc = await WhatsAppFlow.findOneAndUpdate(
            { tenantId: tenant._id.toString(), flowId },
            {
                tenantId: tenant._id.toString(),
                flowId,
                name,
                categories,
                status,
                flowJson: finalFlowJson,
                fieldsConfig,
                ctaText,
                headerText,
                bodyText,
                footerText,
                validationErrors,
                metaLastSyncedAt: new Date()
            },
            { upsert: true, new: true }
        );

        return savedDoc;
    }

    /**
     * Publish an existing DRAFT Flow on Meta WABA
     */
    static async publishFlow(tenant, flowId) {
        const config = tenant.whatsappConfig || {};
        const accessToken = config.accessToken;
        if (!accessToken) {
            throw new Error('WhatsApp Access Token is missing');
        }

        const publishUrl = `${GRAPH_BASE_URL}/${flowId}/publish`;
        const res = await axios.post(
            publishUrl,
            {},
            { headers: { Authorization: `Bearer ${accessToken}` } }
        );

        if (res.data?.success) {
            await WhatsAppFlow.findOneAndUpdate(
                { tenantId: tenant._id.toString(), flowId },
                { status: 'PUBLISHED', metaLastSyncedAt: new Date() }
            );
            return true;
        }
        return false;
    }

    /**
     * Delete or Deprecate a Flow from Meta WABA & DB
     */
    static async deleteFlow(tenant, flowId) {
        const config = tenant.whatsappConfig || {};
        const accessToken = config.accessToken;
        const tenantId = tenant._id.toString();

        const flowDoc = await WhatsAppFlow.findOne({ tenantId, flowId });
        const isDraft = !flowDoc || (flowDoc.status || '').toUpperCase() === 'DRAFT';

        if (accessToken) {
            try {
                if (isDraft) {
                    await axios.delete(`${GRAPH_BASE_URL}/${flowId}`, {
                        headers: { Authorization: `Bearer ${accessToken}` }
                    });
                } else {
                    try {
                        await axios.post(
                            `${GRAPH_BASE_URL}/${flowId}/deprecate`,
                            {},
                            { headers: { Authorization: `Bearer ${accessToken}` } }
                        );
                    } catch (deprecateErr) {
                        console.warn('[WhatsAppFlowService] Deprecate error on Meta:', deprecateErr.response?.data || deprecateErr.message);
                    }
                }
            } catch (metaErr) {
                console.warn('[WhatsAppFlowService] Meta delete error (continuing with local removal):', metaErr.response?.data || metaErr.message);
            }
        }

        // Remove from database
        await WhatsAppFlow.deleteOne({ tenantId, flowId });
        return true;
    }

    /**
     * Send interactive WhatsApp Flow message
     */
    static async sendFlowMessage(tenant, params) {
        const config = tenant.whatsappConfig || {};
        const phoneNumberId = config.phoneNumberId;
        const accessToken = config.accessToken;

        if (!phoneNumberId || !accessToken) {
            throw new Error('WhatsApp Phone Number ID or Access Token is missing');
        }

        const {
            to,
            flowId,
            headerText = '',
            bodyText = 'Please complete the form below:',
            footerText = 'Powered by Sendzyy',
            ctaText = 'Open Form',
            screenId = 'QUESTION_SCREEN',
            flowToken = `ft_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`
        } = params;

        let mode = params.mode;
        let flowDoc = null;
        try {
            flowDoc = await WhatsAppFlow.findOne({ flowId });
        } catch (_) {}

        if (!mode && flowDoc) {
            const statusUpper = (flowDoc.status || '').toUpperCase();
            mode = statusUpper === 'DRAFT' ? 'draft' : undefined;
        } else if (mode !== 'draft') {
            mode = undefined;
        }

        // Dynamically resolve entry screen from flow schema
        let targetScreen = screenId;
        try {
            if (!flowDoc?.flowJson?.screens || flowDoc.flowJson.screens.length === 0) {
                // Fetch asset from Meta if not cached yet
                const assetRes = await axios.get(`${GRAPH_BASE_URL}/${flowId}/assets`, {
                    headers: { Authorization: `Bearer ${accessToken}` }
                });
                const flowJsonAsset = assetRes.data?.data?.find(a => a.asset_type === 'FLOW_JSON');
                if (flowJsonAsset?.download_url) {
                    const jsonRes = await axios.get(flowJsonAsset.download_url);
                    if (jsonRes.data?.screens) {
                        flowDoc = await WhatsAppFlow.findOneAndUpdate(
                            { flowId },
                            { flowJson: jsonRes.data },
                            { returnDocument: 'after' }
                        );
                    }
                }
            }

            const validScreenIds = flowDoc?.flowJson?.screens?.map(s => s.id) || [];
            if (validScreenIds.length > 0) {
                if (!targetScreen || !validScreenIds.includes(targetScreen)) {
                    targetScreen = validScreenIds[0];
                }
            }
        } catch (screenErr) {
            console.warn('[WhatsAppFlowService] Screen discovery notice:', screenErr.message);
        }

        if (!targetScreen) {
            targetScreen = 'QUESTION_SCREEN';
        }

        const actionParameters = {
            flow_message_version: '3',
            flow_token: flowToken,
            flow_id: flowId,
            flow_cta: ctaText,
            flow_action: 'navigate',
            flow_action_payload: {
                screen: targetScreen
            }
        };

        if (mode === 'draft') {
            actionParameters.mode = 'draft';
        }

        const payload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: to.replace(/[^0-9]/g, ''),
            type: 'interactive',
            interactive: {
                type: 'flow',
                header: headerText ? { type: 'text', text: headerText } : undefined,
                body: { text: bodyText },
                footer: footerText ? { text: footerText } : undefined,
                action: {
                    name: 'flow',
                    parameters: actionParameters
                }
            }
        };

        const sendUrl = `${GRAPH_BASE_URL}/${phoneNumberId}/messages`;
        const res = await axios.post(sendUrl, payload, {
            headers: { Authorization: `Bearer ${accessToken}` }
        });

        const wamid = res.data?.messages?.[0]?.id;
        return { wamid, flowToken };
    }
}

module.exports = {
    WhatsAppFlowService,
    compileFieldsToFlowJson
};
