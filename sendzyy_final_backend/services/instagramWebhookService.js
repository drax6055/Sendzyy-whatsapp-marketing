const axios = require('axios');
const InstagramCommentAutomation = require('../models/InstagramCommentAutomation');
const InstagramProcessedComment = require('../models/InstagramProcessedComment');
const InstagramConversation = require('../models/InstagramConversation');
const InstagramMessage = require('../models/InstagramMessage');
const SocketEmitter = require('./SocketEmitter');

/**
 * Fetch Instagram User Profile (Name, Username, Profile Pic) via Graph API
 */
async function fetchInstagramUserProfile(igsid, accessToken) {
    if (!igsid || !accessToken) return null;
    const apiVer = (process.env.INSTA_META_API_VERSION || process.env.META_API_VERSION || 'v26.0').toLowerCase();
    try {
        const response = await axios.get(`https://graph.instagram.com/${apiVer}/${igsid}`, {
            params: { fields: 'name,username,profile_pic', access_token: accessToken },
            timeout: 5000
        });
        return response.data;
    } catch (err1) {
        try {
            const fbResponse = await axios.get(`https://graph.facebook.com/${apiVer}/${igsid}`, {
                params: { fields: 'name,username,profile_pic', access_token: accessToken },
                timeout: 5000
            });
            return fbResponse.data;
        } catch (err2) {
            return null;
        }
    }
}

/**
 * Process incoming Instagram / Page DM & Comment Webhooks
 */
async function handleInstagramWebhook(req, res, body, Tenant, InstagramAutomation, InstagramAutomationSession) {
    if (!res.headersSent) {
        res.sendStatus(200); // Respond immediately to Meta SLA
    }
    console.log('[IG WEBHOOK] 📥 Received Instagram/Page webhook. Object:', body.object);

    try {
        for (const entry of body.entry || []) {
            const entryId = entry.id;

            // ── Handle Instagram Comment Events (entry.changes) ──────────────────
            if (entry.changes && entry.changes.length > 0) {
                console.log(`[IG WEBHOOK] Found ${entry.changes.length} change event(s) in entry ${entryId}`);
                try {
                    await handleCommentChanges(entry, Tenant);
                } catch (commentErr) {
                    console.error('[IG COMMENT WEBHOOK] ❌ Error in handleCommentChanges:', commentErr.message, commentErr.stack);
                }
            }

            const messagingEvents = entry.messaging || entry.standby || [];
            console.log(`[IG WEBHOOK] Found ${messagingEvents.length} messaging event(s) in entry ${entryId}`);

            for (const messaging of messagingEvents) {
                const senderId = messaging.sender?.id;
                const recipientId = messaging.recipient?.id;

                if (!senderId || !recipientId) {
                    console.warn('[IG WEBHOOK] ⚠️ Missing senderId or recipientId, skipping.');
                    continue;
                }

                // Find tenant by matching recipientId, senderId, entryId, or igUserId
                let resolvedTenant = await Tenant.findOne({
                    $or: [
                        { 'instagramConfig.instagramAccountId': recipientId },
                        { 'instagramConfig.instagramAccountId': senderId },
                        { 'instagramConfig.instagramAccountId': entryId },
                        { 'instagramConfig.igUserId': recipientId },
                        { 'instagramConfig.igUserId': entryId }
                    ],
                    'instagramConfig.connected': true
                });

                if (!resolvedTenant) {
                    const connectedTenants = await Tenant.find({ 'instagramConfig.connected': true });
                    if (connectedTenants.length > 0) {
                        resolvedTenant = connectedTenants[0];
                        console.log(`[IG WEBHOOK] 💡 Auto-matching incoming IG webhook (recipient: ${recipientId}, entry: ${entryId}) to tenant: ${resolvedTenant._id}`);
                        resolvedTenant.instagramConfig.igUserId = recipientId;
                        await resolvedTenant.save();
                    }
                }

                if (!resolvedTenant) {
                    console.warn('[IG WEBHOOK] ⚠️ No tenant found for recipientId:', recipientId, '| senderId:', senderId, '| entryId:', entryId);
                    continue;
                }

                const tenantId = resolvedTenant._id.toString();
                const accessToken = resolvedTenant.instagramConfig.accessToken;
                const igUserId = resolvedTenant.instagramConfig.igUserId || resolvedTenant.instagramConfig.instagramAccountId;
                const isEcho = Boolean(messaging.message?.is_echo);

                // Determine actual IGSID of customer
                const actualSenderId = (senderId === igUserId || senderId === resolvedTenant.instagramConfig.instagramAccountId || senderId === entryId || isEcho)
                    ? recipientId
                    : senderId;

                console.log(`[IG WEBHOOK] ✅ Tenant matched: ${tenantId} | igUserId: ${igUserId} | actualSenderId: ${actualSenderId} | isEcho: ${isEcho}`);

                // ── Handle Delivery Receipts ─────────────────────────────────────────
                if (messaging.delivery) {
                    const mids = messaging.delivery.mids || [];
                    if (mids.length > 0) {
                        await InstagramMessage.updateMany(
                            { mid: { $in: mids } },
                            { $set: { status: 'delivered' } }
                        );
                        SocketEmitter._io?.to(tenantId).emit('instagram:message_status', { mids, status: 'delivered' });
                    }
                    continue;
                }

                // ── Handle Read Receipts ─────────────────────────────────────────────
                if (messaging.read) {
                    const watermark = messaging.read.watermark;
                    if (watermark) {
                        await InstagramMessage.updateMany(
                            { tenantId, igsid: actualSenderId, isMe: true, timestamp: { $lte: new Date(watermark) } },
                            { $set: { status: 'read' } }
                        );
                        SocketEmitter._io?.to(tenantId).emit('instagram:message_status', { igsid: actualSenderId, status: 'read', watermark });
                    }
                    continue;
                }

                // ── Handle Outgoing Echo Message (Sent by business account) ──────────
                if (isEcho) {
                    const echoMid = messaging.message?.mid;
                    const echoText = messaging.message?.text || '';
                    const echoTimestamp = new Date(messaging.timestamp || Date.now());

                    let conv = await InstagramConversation.findOne({ tenantId, instagramAccountId: igUserId, igsid: actualSenderId });
                    if (!conv) {
                        conv = new InstagramConversation({
                            tenantId,
                            instagramAccountId: igUserId,
                            igsid: actualSenderId,
                            name: `User ${actualSenderId.slice(-4)}`,
                            lastMessage: echoText,
                            lastMessageAt: echoTimestamp,
                            isHumanTakeover: true,
                            status: 'active'
                        });
                        await conv.save();
                    } else {
                        conv.lastMessage = echoText || conv.lastMessage;
                        conv.lastMessageAt = echoTimestamp;
                        await conv.save();
                    }

                    let existingMsg = echoMid ? await InstagramMessage.findOne({ mid: echoMid }) : null;
                    if (!existingMsg && echoText) {
                        existingMsg = await InstagramMessage.create({
                            tenantId,
                            conversationId: conv._id,
                            igsid: actualSenderId,
                            isMe: true,
                            senderType: 'agent',
                            text: echoText,
                            mid: echoMid,
                            status: 'sent',
                            timestamp: echoTimestamp
                        });
                        SocketEmitter._io?.to(tenantId).emit('instagram:message_received', {
                            conversation: conv.toObject ? conv.toObject() : conv,
                            message: existingMsg.toObject ? existingMsg.toObject() : existingMsg
                        });
                    }
                    SocketEmitter._io?.to(tenantId).emit('instagram:conversation_updated', conv.toObject ? conv.toObject() : conv);
                    continue; // Skip bot automation for echoes
                }

                // ── Extract Incoming Customer Message Data ───────────────────────────
                const messageMid = messaging.message?.mid || '';
                const incomingText = messaging.message?.text || messaging.postback?.title || '';
                const quickReplyPayload = messaging.message?.quick_reply?.payload || messaging.postback?.payload;
                const attachments = messaging.message?.attachments || [];
                let messageType = 'text';
                let mediaUrl = '';
                if (attachments.length > 0) {
                    messageType = attachments[0].type || 'media';
                    mediaUrl = attachments[0].payload?.url || '';
                }

                const eventTime = new Date(messaging.timestamp || Date.now());

                // Find or create conversation
                let conversation = await InstagramConversation.findOne({
                    tenantId,
                    instagramAccountId: igUserId,
                    igsid: actualSenderId
                });

                const displayPreview = incomingText || (mediaUrl ? `[${messageType}]` : (quickReplyPayload ? `[Selected: ${quickReplyPayload}]` : 'New Message'));

                if (!conversation) {
                    conversation = new InstagramConversation({
                        tenantId,
                        instagramAccountId: igUserId,
                        igsid: actualSenderId,
                        name: `User ${actualSenderId.slice(-4)}`,
                        username: '',
                        profilePic: '',
                        lastMessage: displayPreview,
                        lastMessageAt: eventTime,
                        lastCustomerMessageAt: eventTime,
                        unreadCount: 1,
                        isHumanTakeover: false,
                        status: 'active'
                    });
                    await conversation.save();

                    // Fetch user profile asynchronously from Meta Graph API
                    fetchInstagramUserProfile(actualSenderId, accessToken).then(async (profile) => {
                        if (profile && (profile.name || profile.username || profile.profile_pic)) {
                            await InstagramConversation.updateOne(
                                { _id: conversation._id },
                                {
                                    $set: {
                                        name: profile.name || profile.username || conversation.name,
                                        username: profile.username || '',
                                        profilePic: profile.profile_pic || ''
                                    }
                                }
                            );
                            const updated = await InstagramConversation.findById(conversation._id).lean();
                            SocketEmitter._io?.to(tenantId).emit('instagram:conversation_updated', updated);
                        }
                    }).catch(err => console.warn('[IG WEBHOOK] Profile fetch notice:', err.message));
                } else {
                    conversation.lastMessage = displayPreview;
                    conversation.lastMessageAt = eventTime;
                    conversation.lastCustomerMessageAt = eventTime;
                    conversation.unreadCount = (conversation.unreadCount || 0) + 1;
                    await conversation.save();

                    // Enrich profile if username still blank
                    if (!conversation.username) {
                        fetchInstagramUserProfile(actualSenderId, accessToken).then(async (profile) => {
                            if (profile && (profile.name || profile.username || profile.profile_pic)) {
                                await InstagramConversation.updateOne(
                                    { _id: conversation._id },
                                    {
                                        $set: {
                                            name: profile.name || profile.username || conversation.name,
                                            username: profile.username || '',
                                            profilePic: profile.profile_pic || ''
                                        }
                                    }
                                );
                                const updated = await InstagramConversation.findById(conversation._id).lean();
                                SocketEmitter._io?.to(tenantId).emit('instagram:conversation_updated', updated);
                            }
                        }).catch(err => console.warn('[IG WEBHOOK] Profile fetch notice:', err.message));
                    }
                }

                // Save incoming message in MongoDB
                let savedIncomingMessage = null;
                if (messageMid) {
                    savedIncomingMessage = await InstagramMessage.findOne({ mid: messageMid });
                }
                if (!savedIncomingMessage && (incomingText || mediaUrl || quickReplyPayload)) {
                    savedIncomingMessage = await InstagramMessage.create({
                        tenantId,
                        conversationId: conversation._id,
                        igsid: actualSenderId,
                        isMe: false,
                        senderType: 'customer',
                        text: incomingText || (quickReplyPayload ? `[Clicked: ${quickReplyPayload}]` : ''),
                        messageType,
                        mediaUrl,
                        mid: messageMid,
                        status: 'delivered',
                        timestamp: eventTime
                    });
                }

                // Emit real-time updates via Socket.IO
                const convObj = conversation.toObject ? conversation.toObject() : conversation;
                if (savedIncomingMessage) {
                    SocketEmitter._io?.to(tenantId).emit('instagram:message_received', {
                        conversation: convObj,
                        message: savedIncomingMessage.toObject ? savedIncomingMessage.toObject() : savedIncomingMessage
                    });
                }
                SocketEmitter._io?.to(tenantId).emit('instagram:conversation_updated', convObj);

                // ── Check Human-Agent Takeover ───────────────────────────────────────
                if (conversation.isHumanTakeover) {
                    console.log(`[IG WEBHOOK] 🧑‍💼 Human agent takeover is ACTIVE for IGSID: ${actualSenderId}. Bot automation suppressed.`);
                    continue; // Skip automated bot response when human agent is in control
                }

                // ── Helper to split message if exceeding 1,000 char limit ───────────
                const splitInstagramMessage = (text, maxLen = 950) => {
                    if (!text || text.length <= maxLen) return [text];
                    const chunks = [];
                    let remaining = text;
                    while (remaining.length > 0) {
                        if (remaining.length <= maxLen) {
                            chunks.push(remaining);
                            break;
                        }
                        let splitIndex = remaining.lastIndexOf('\n\n', maxLen);
                        if (splitIndex === -1 || splitIndex < maxLen * 0.5) {
                            splitIndex = remaining.lastIndexOf('\n', maxLen);
                        }
                        if (splitIndex === -1 || splitIndex < maxLen * 0.5) {
                            splitIndex = remaining.lastIndexOf(' ', maxLen);
                        }
                        if (splitIndex === -1) {
                            splitIndex = maxLen;
                        }
                        chunks.push(remaining.substring(0, splitIndex).trim());
                        remaining = remaining.substring(splitIndex).trim();
                    }
                    return chunks.filter(c => c.length > 0);
                };

                // Helper: send single message chunk via Instagram Graph API
                const sendSingleMessage = async (msgPayload) => {
                    const apiVer = (process.env.INSTA_META_API_VERSION || process.env.META_API_VERSION || 'v26.0').toLowerCase();
                    console.log(`[IG WEBHOOK] 📤 Dispatching message to IGSID: ${actualSenderId} via Graph API (${apiVer})`);
                    try {
                        const response = await axios.post(
                            `https://graph.instagram.com/${apiVer}/${igUserId}/messages`,
                            msgPayload,
                            { headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' } }
                        );
                        return response.data;
                    } catch (err) {
                        try {
                            const fbResponse = await axios.post(
                                `https://graph.facebook.com/${apiVer}/${igUserId}/messages`,
                                msgPayload,
                                { headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' } }
                            );
                            return fbResponse.data;
                        } catch (fbErr) {
                            console.error('[IG WEBHOOK] ❌ graph API send failed:', fbErr.response?.data || fbErr.message);
                            throw fbErr;
                        }
                    }
                };

                // Helper: send message with splitting and record in database + socket emit
                const sendInstagramMessage = async (payload, automationDoc = null) => {
                    const rawText = payload.message?.text || '';
                    const quickReplies = payload.message?.quick_replies;
                    let lastSentResult = null;

                    if (rawText.length > 1000) {
                        const chunks = splitInstagramMessage(rawText, 950);
                        for (let i = 0; i < chunks.length; i++) {
                            const isLast = i === chunks.length - 1;
                            const chunkPayload = {
                                recipient: payload.recipient,
                                messaging_type: payload.messaging_type || 'RESPONSE',
                                message: {
                                    text: chunks[i],
                                    ...(isLast && quickReplies && quickReplies.length > 0 && { quick_replies: quickReplies })
                                }
                            };
                            lastSentResult = await sendSingleMessage(chunkPayload);
                            if (!isLast) await new Promise(r => setTimeout(r, 500));
                        }
                    } else {
                        lastSentResult = await sendSingleMessage(payload);
                    }

                    // Record automated bot reply in database and emit real-time
                    try {
                        const botMessage = await InstagramMessage.create({
                            tenantId,
                            conversationId: conversation._id,
                            igsid: actualSenderId,
                            isMe: true,
                            senderType: 'automation',
                            text: rawText,
                            quickReplies: quickReplies ? quickReplies.map(qr => ({ title: qr.title, payload: qr.payload })) : [],
                            mid: lastSentResult?.message_id || '',
                            status: 'sent',
                            timestamp: new Date()
                        });

                        conversation.lastMessage = rawText;
                        conversation.lastMessageAt = new Date();
                        await conversation.save();

                        SocketEmitter._io?.to(tenantId).emit('instagram:message_received', {
                            conversation: conversation.toObject ? conversation.toObject() : conversation,
                            message: botMessage.toObject ? botMessage.toObject() : botMessage
                        });
                        SocketEmitter._io?.to(tenantId).emit('instagram:conversation_updated', conversation.toObject ? conversation.toObject() : conversation);
                    } catch (recordErr) {
                        console.error('[IG WEBHOOK] Error saving automated reply to DB:', recordErr.message);
                    }
                };

                // ── Case 1: Quick Reply / Postback Clicked ───────────────────────────
                if (quickReplyPayload) {
                    console.log(`[IG WEBHOOK] 🔘 Quick reply / postback clicked! Payload: "${quickReplyPayload}" | from IGSID: ${actualSenderId}`);
                    const automations = await InstagramAutomation.find({ tenantId, isActive: true });
                    let responded = false;

                    for (const automation of automations) {
                        let responseText = null;
                        if (automation.payloadResponses) {
                            if (typeof automation.payloadResponses.get === 'function') {
                                responseText = automation.payloadResponses.get(quickReplyPayload);
                                if (!responseText) {
                                    for (const [k, v] of automation.payloadResponses.entries()) {
                                        if (String(k).trim().toLowerCase() === String(quickReplyPayload).trim().toLowerCase()) {
                                            responseText = v;
                                            break;
                                        }
                                    }
                                }
                            } else if (typeof automation.payloadResponses === 'object') {
                                responseText = automation.payloadResponses[quickReplyPayload];
                                if (!responseText) {
                                    for (const [k, v] of Object.entries(automation.payloadResponses)) {
                                        if (String(k).trim().toLowerCase() === String(quickReplyPayload).trim().toLowerCase()) {
                                            responseText = v;
                                            break;
                                        }
                                    }
                                }
                            }
                        }

                        if (responseText) {
                            console.log(`[IG WEBHOOK] 🎯 Matched quick reply payload "${quickReplyPayload}" in rule "${automation.name}". Response: "${responseText}"`);
                            await sendInstagramMessage({
                                recipient: { id: actualSenderId },
                                messaging_type: 'RESPONSE',
                                message: { text: responseText }
                            }, automation);
                            responded = true;
                            break;
                        }
                    }
                    continue;
                }

                // ── Case 2: Regular Incoming DM Text ─────────────────────────────────
                if (incomingText) {
                    const textLower = incomingText.trim().toLowerCase();
                    const automations = await InstagramAutomation.find({ tenantId, isActive: true }).sort({ createdAt: 1 });

                    if (!automations.length) continue;

                    let matched = null;

                    // Priority 1: Keyword Triggers
                    for (const auto of automations) {
                        if (auto.triggerType === 'keyword') {
                            const keywords = (auto.triggerKeywords || []).map(k => k.trim().toLowerCase()).filter(Boolean);
                            if (keywords.some(k => textLower.includes(k))) {
                                matched = auto;
                                break;
                            }
                        }
                    }

                    // Priority 2: Fallback to Any DM trigger
                    if (!matched) {
                        for (const auto of automations) {
                            if (auto.triggerType === 'any_dm') {
                                matched = auto;
                                break;
                            }
                        }
                    }

                    if (!matched) continue;

                    // 24h Cooldown for 'any_dm' triggers only
                    if (matched.triggerType === 'any_dm') {
                        const sessionKey = { tenantId, igsid: actualSenderId };
                        const existingSession = await InstagramAutomationSession.findOne(sessionKey);
                        if (existingSession && existingSession.lastTriggerAt) {
                            const hoursSince = (Date.now() - existingSession.lastTriggerAt.getTime()) / (1000 * 60 * 60);
                            if (hoursSince < 24) {
                                console.log(`[IG WEBHOOK] ⏳ Any DM trigger already sent within 24h, skipping.`);
                                continue;
                            }
                            existingSession.automationId = matched._id.toString();
                            existingSession.lastTriggerAt = new Date();
                            await existingSession.save();
                        } else {
                            await InstagramAutomationSession.create({
                                tenantId,
                                igsid: actualSenderId,
                                automationId: matched._id.toString(),
                                lastTriggerAt: new Date()
                            });
                        }
                    }

                    // Build quick replies payload if configured
                    const messagePayload = {
                        recipient: { id: actualSenderId },
                        messaging_type: 'RESPONSE',
                        message: {
                            text: matched.replyMessage,
                            ...(matched.quickReplies && matched.quickReplies.length > 0 && {
                                quick_replies: matched.quickReplies.map(qr => ({
                                    content_type: 'text',
                                    title: qr.title,
                                    payload: qr.payload
                                }))
                            })
                        }
                    };

                    await sendInstagramMessage(messagePayload, matched);
                }
            }
        }
    } catch (err) {
        console.error('[IG WEBHOOK] ❌ Critical error handling webhook:', err.message, err.stack);
    }
}

/**
 * Handle incoming Instagram Comment Webhook Events
 */
async function handleCommentChanges(entry, Tenant) {
    const entryId = entry.id;
    const commentChanges = (entry.changes || []).filter(c => c.field === 'comments' && c.value);
    if (!commentChanges.length) return;

    // Find tenant matching account
    let resolvedTenant = await Tenant.findOne({
        $or: [
            { 'instagramConfig.instagramAccountId': entryId },
            { 'instagramConfig.igUserId': entryId }
        ],
        'instagramConfig.connected': true
    });

    if (!resolvedTenant) {
        const connectedTenants = await Tenant.find({ 'instagramConfig.connected': true });
        if (connectedTenants.length > 0) {
            resolvedTenant = connectedTenants[0];
        }
    }

    if (!resolvedTenant) {
        console.warn('[IG COMMENT WEBHOOK] No connected tenant found for entryId:', entryId);
        return;
    }

    const tenantId = resolvedTenant._id.toString();
    const accessToken = resolvedTenant.instagramConfig.accessToken;
    const igUserId = resolvedTenant.instagramConfig.igUserId || resolvedTenant.instagramConfig.instagramAccountId;
    const igUsername = resolvedTenant.instagramConfig.username || '';
    const apiVer = (process.env.INSTA_META_API_VERSION || process.env.META_API_VERSION || 'v26.0').toLowerCase();

    for (const change of commentChanges) {
        const value = change.value || {};
        const commentId = value.id;
        const commentText = (value.text || '').trim();
        const fromUser = value.from || {};
        const fromUsername = fromUser.username || '';
        const fromUserId = fromUser.id || '';
        const mediaId = value.media?.id || '';

        if (!commentId) continue;

        // Skip if comment is from the connected business account itself (prevent self-loop)
        if (
            fromUserId === resolvedTenant.instagramConfig.instagramAccountId ||
            fromUserId === resolvedTenant.instagramConfig.igUserId ||
            (igUsername && fromUsername.toLowerCase() === igUsername.toLowerCase())
        ) {
            console.log('[IG COMMENT WEBHOOK] Comment is from own Instagram account, skipping self-reply.');
            continue;
        }

        // Skip if this comment has already been processed (idempotency)
        const alreadyProcessed = await InstagramProcessedComment.findOne({ commentId });
        if (alreadyProcessed) {
            console.log(`[IG COMMENT WEBHOOK] Comment ${commentId} already processed. Skipping duplicate.`);
            continue;
        }

        // Find active comment automations
        const automations = await InstagramCommentAutomation.find({
            tenantId,
            isActive: true
        }).sort({ createdAt: 1 });

        if (!automations.length) {
            console.log('[IG COMMENT WEBHOOK] No active comment automations found for tenant:', tenantId);
            continue;
        }

        let matched = null;
        for (const auto of automations) {
            // Check post matching
            if (auto.postSelectionType === 'specific') {
                const selectedMediaIds = (auto.selectedMedia || []).map(m => m.id);
                if (!selectedMediaIds.includes(mediaId)) {
                    continue; // Specific post does not match
                }
            }

            // Check keyword matching
            if (auto.triggerType === 'all') {
                matched = auto;
                break;
            } else if (auto.triggerType === 'keyword') {
                const lowerText = commentText.toLowerCase();
                const matchedKw = (auto.triggerKeywords || []).some(kw =>
                    lowerText.includes(kw.trim().toLowerCase())
                );
                if (matchedKw) {
                    matched = auto;
                    break;
                }
            }
        }

        if (!matched) {
            console.log(`[IG COMMENT WEBHOOK] No matching comment automation rule for comment "${commentText}" on media ${mediaId}`);
            continue;
        }

        console.log(`[IG COMMENT WEBHOOK] ✅ Matched automation: "${matched.name}" (ID: ${matched._id})`);

        const processedRecord = new InstagramProcessedComment({
            tenantId,
            commentId,
            mediaId,
            fromUsername,
            fromUserId,
            commentText,
            automationId: matched._id
        });

        // 1. Send Public Reply to Comment (Optional)
        if (matched.sendPublicReply && matched.publicReplyMessage && matched.publicReplyMessage.trim()) {
            const publicMessage = matched.publicReplyMessage
                .replace(/@?\{\{username\}\}/gi, fromUsername ? `@${fromUsername}` : '')
                .replace(/@?\{username\}/gi, fromUsername ? `@${fromUsername}` : '');

            try {
                console.log(`[IG COMMENT WEBHOOK] Posting public reply: "${publicMessage}" to comment ${commentId}`);
                await axios.post(
                    `https://graph.instagram.com/${apiVer}/${commentId}/replies`,
                    { message: publicMessage },
                    { headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' } }
                );
                processedRecord.publicReplied = true;
                console.log('[IG COMMENT WEBHOOK] ✅ Public reply posted successfully.');
            } catch (pubErr) {
                console.error('[IG COMMENT WEBHOOK] ❌ graph.instagram.com public reply failed:', pubErr.response?.data || pubErr.message);
                try {
                    await axios.post(
                        `https://graph.facebook.com/${apiVer}/${commentId}/replies`,
                        { message: publicMessage },
                        { headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' } }
                    );
                    processedRecord.publicReplied = true;
                    console.log('[IG COMMENT WEBHOOK] ✅ Fallback public reply posted successfully.');
                } catch (fbErr) {
                    console.error('[IG COMMENT WEBHOOK] ❌ Fallback public reply failed:', fbErr.response?.data || fbErr.message);
                    processedRecord.error = 'Public reply failed: ' + (pubErr.response?.data?.error?.message || pubErr.message);
                }
            }
        }

        // 2. Send Private DM to the Commenter
        if (matched.sendPrivateDm && matched.privateDmMessage && matched.privateDmMessage.trim()) {
            const privateMessage = matched.privateDmMessage
                .replace(/\{\{username\}\}/gi, fromUsername || '')
                .replace(/\{username\}/gi, fromUsername || '');

            const dmPayload = {
                recipient: {
                    comment_id: commentId
                },
                message: {
                    text: privateMessage
                }
            };

            try {
                console.log(`[IG COMMENT WEBHOOK] Sending private DM for comment ${commentId} to @${fromUsername}: "${privateMessage}"`);
                await axios.post(
                    `https://graph.instagram.com/${apiVer}/${igUserId}/messages`,
                    dmPayload,
                    { headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' } }
                );
                processedRecord.privateDmSent = true;
                console.log('[IG COMMENT WEBHOOK] ✅ Private DM sent successfully.');
            } catch (dmErr) {
                console.error('[IG COMMENT WEBHOOK] ❌ graph.instagram.com private DM failed:', dmErr.response?.data || dmErr.message);
                try {
                    await axios.post(
                        `https://graph.facebook.com/${apiVer}/${igUserId}/messages`,
                        dmPayload,
                        { headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' } }
                    );
                    processedRecord.privateDmSent = true;
                    console.log('[IG COMMENT WEBHOOK] ✅ Fallback private DM sent successfully.');
                } catch (fbDmErr) {
                    console.error('[IG COMMENT WEBHOOK] ❌ Fallback private DM failed:', fbDmErr.response?.data || fbDmErr.message);
                    processedRecord.error = (processedRecord.error ? processedRecord.error + '; ' : '') +
                        'Private DM failed: ' + (dmErr.response?.data?.error?.message || dmErr.message);
                }
            }
        }

        try {
            await processedRecord.save();
        } catch (saveErr) {
            console.error('[IG COMMENT WEBHOOK] Error saving processed comment record:', saveErr.message);
        }
    }
}

module.exports = {
    handleInstagramWebhook,
    handleCommentChanges
};
