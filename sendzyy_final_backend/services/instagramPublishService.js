const axios = require('axios');
const InstagramPost = require('../models/InstagramPost');

const getApiVersion = () => {
    return (process.env.INSTA_META_API_VERSION || process.env.META_API_VERSION || 'v26.0').toLowerCase();
};

/**
 * Poll container processing status until FINISHED or error
 */
async function pollContainerStatus(creationId, accessToken, maxAttempts = 25, delayMs = 3000) {
    const apiVer = getApiVersion();
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
            let res;
            try {
                res = await axios.get(`https://graph.instagram.com/${apiVer}/${creationId}`, {
                    params: {
                        fields: 'status_code,status',
                        access_token: accessToken
                    },
                    timeout: 15000
                });
            } catch (err) {
                // Fallback to graph.facebook.com
                res = await axios.get(`https://graph.facebook.com/${apiVer}/${creationId}`, {
                    params: {
                        fields: 'status_code,status',
                        access_token: accessToken
                    },
                    timeout: 15000
                });
            }

            const statusCode = res.data?.status_code || res.data?.status;
            console.log(`[IG Publish Polling] Container ${creationId} status: ${statusCode} (attempt ${attempt}/${maxAttempts})`);

            if (statusCode === 'FINISHED' || statusCode === 'PUBLISHED') {
                return true;
            }

            if (statusCode === 'ERROR' || statusCode === 'EXPIRED') {
                throw new Error(`Media container processing failed with status: ${statusCode}`);
            }

            // Still IN_PROGRESS, wait and retry
            await new Promise((resolve) => setTimeout(resolve, delayMs));
        } catch (error) {
            if (error.message.includes('Media container processing failed')) {
                throw error;
            }
            console.warn(`[IG Publish Polling] Warning on attempt ${attempt}:`, error.response?.data || error.message);
            if (attempt === maxAttempts) {
                throw error;
            }
            await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
    }

    // After max attempts, proceed with publish attempt (some simple images may be ready)
    return true;
}

/**
 * Helper to call Instagram Graph API with fallback to Facebook Graph API
 */
async function callInstagramApi(method, path, data = {}, params = {}) {
    const apiVer = getApiVersion();
    const cleanPath = path.startsWith('/') ? path.slice(1) : path;
    const igUrl = `https://graph.instagram.com/${apiVer}/${cleanPath}`;
    const fbUrl = `https://graph.facebook.com/${apiVer}/${cleanPath}`;

    try {
        if (method.toUpperCase() === 'POST') {
            return await axios.post(igUrl, data, { params, timeout: 30000 });
        } else {
            return await axios.get(igUrl, { params, timeout: 30000 });
        }
    } catch (igErr) {
        console.warn(`[IG Publish API] graph.instagram.com failed, trying graph.facebook.com...`, igErr.response?.data || igErr.message);
        if (method.toUpperCase() === 'POST') {
            return await axios.post(fbUrl, data, { params, timeout: 30000 });
        } else {
            return await axios.get(fbUrl, { params, timeout: 30000 });
        }
    }
}

/**
 * Service to publish and schedule Instagram content via official Meta Instagram Graph API
 */
const instagramPublishService = {
    /**
     * Build formatted caption including hashtags
     */
    buildCaption(baseCaption = '', hashtags = []) {
        let finalCaption = (baseCaption || '').trim();
        if (Array.isArray(hashtags) && hashtags.length > 0) {
            const formattedTags = hashtags
                .map(t => t.trim())
                .filter(Boolean)
                .map(t => (t.startsWith('#') ? t : `#${t}`))
                .join(' ');
            if (formattedTags) {
                finalCaption = finalCaption ? `${finalCaption}\n\n${formattedTags}` : formattedTags;
            }
        }
        return finalCaption;
    },

    /**
     * Publish Single Image
     */
    async publishSinglePhoto({ igUserId, accessToken, imageUrl, caption, userTags, locationId }) {
        console.log(`[IG Publish] Creating container for single photo on IG account ${igUserId}...`);

        const params = {
            image_url: imageUrl,
            access_token: accessToken
        };
        if (caption) params.caption = caption;
        if (locationId) params.location_id = locationId;
        if (Array.isArray(userTags) && userTags.length > 0) {
            params.user_tags = JSON.stringify(
                userTags.map(tag => ({
                    username: tag.username.replace('@', '').trim(),
                    x: typeof tag.x === 'number' ? tag.x : 0.5,
                    y: typeof tag.y === 'number' ? tag.y : 0.5
                }))
            );
        }

        const containerRes = await callInstagramApi('POST', `${igUserId}/media`, params);
        const creationId = containerRes.data?.id;
        if (!creationId) {
            throw new Error('Meta API did not return container creation_id for single photo');
        }

        console.log(`[IG Publish] Photo container created with ID: ${creationId}. Polling status...`);
        await pollContainerStatus(creationId, accessToken, 15, 2000);

        console.log(`[IG Publish] Publishing container ${creationId}...`);
        const publishRes = await callInstagramApi('POST', `${igUserId}/media_publish`, {
            creation_id: creationId,
            access_token: accessToken
        });

        return {
            creationId,
            igMediaId: publishRes.data?.id
        };
    },

    /**
     * Publish Reel (Video)
     */
    async publishReel({ igUserId, accessToken, videoUrl, caption, locationId }) {
        console.log(`[IG Publish] Creating container for Reel on IG account ${igUserId}...`);

        const params = {
            media_type: 'REELS',
            video_url: videoUrl,
            share_to_feed: true,
            access_token: accessToken
        };
        if (caption) params.caption = caption;
        if (locationId) params.location_id = locationId;

        const containerRes = await callInstagramApi('POST', `${igUserId}/media`, params);
        const creationId = containerRes.data?.id;
        if (!creationId) {
            throw new Error('Meta API did not return container creation_id for Reel');
        }

        console.log(`[IG Publish] Reel container created with ID: ${creationId}. Polling video transcoding status...`);
        // Video transcoding on Meta can take longer (up to 90 seconds)
        await pollContainerStatus(creationId, accessToken, 30, 3000);

        console.log(`[IG Publish] Publishing Reel container ${creationId}...`);
        const publishRes = await callInstagramApi('POST', `${igUserId}/media_publish`, {
            creation_id: creationId,
            access_token: accessToken
        });

        return {
            creationId,
            igMediaId: publishRes.data?.id
        };
    },

    /**
     * Publish Carousel (Album of 2-10 photos/videos)
     */
    async publishCarousel({ igUserId, accessToken, mediaUrls, caption, userTags, locationId }) {
        if (!Array.isArray(mediaUrls) || mediaUrls.length < 2 || mediaUrls.length > 10) {
            throw new Error('Carousel requires between 2 and 10 media items');
        }

        console.log(`[IG Publish] Creating ${mediaUrls.length} carousel item containers...`);
        const childrenIds = [];

        for (let idx = 0; idx < mediaUrls.length; idx++) {
            const url = mediaUrls[idx];
            const isVideo = url.toLowerCase().endsWith('.mp4') || url.toLowerCase().endsWith('.mov');
            const itemParams = {
                is_carousel_item: true,
                access_token: accessToken
            };

            if (isVideo) {
                itemParams.media_type = 'VIDEO';
                itemParams.video_url = url;
            } else {
                itemParams.image_url = url;
                if (idx === 0 && Array.isArray(userTags) && userTags.length > 0) {
                    itemParams.user_tags = JSON.stringify(
                        userTags.map(tag => ({
                            username: tag.username.replace('@', '').trim(),
                            x: typeof tag.x === 'number' ? tag.x : 0.5,
                            y: typeof tag.y === 'number' ? tag.y : 0.5
                        }))
                    );
                }
            }

            const itemRes = await callInstagramApi('POST', `${igUserId}/media`, itemParams);
            const itemId = itemRes.data?.id;
            if (!itemId) {
                throw new Error(`Failed to create carousel item container for index ${idx}`);
            }

            console.log(`[IG Publish] Carousel item ${idx + 1}/${mediaUrls.length} container ID: ${itemId}. Polling status...`);
            await pollContainerStatus(itemId, accessToken, 20, 2500);
            childrenIds.push(itemId);
        }

        console.log(`[IG Publish] All carousel items ready. Creating parent Carousel container with children: ${childrenIds.join(',')}...`);
        const carouselParams = {
            media_type: 'CAROUSEL',
            children: childrenIds.join(','),
            access_token: accessToken
        };
        if (caption) carouselParams.caption = caption;
        if (locationId) carouselParams.location_id = locationId;

        const carouselRes = await callInstagramApi('POST', `${igUserId}/media`, carouselParams);
        const carouselCreationId = carouselRes.data?.id;
        if (!carouselCreationId) {
            throw new Error('Meta API did not return container creation_id for Carousel');
        }

        console.log(`[IG Publish] Parent Carousel container ID: ${carouselCreationId}. Polling status...`);
        await pollContainerStatus(carouselCreationId, accessToken, 20, 2500);

        console.log(`[IG Publish] Publishing parent Carousel container ${carouselCreationId}...`);
        const publishRes = await callInstagramApi('POST', `${igUserId}/media_publish`, {
            creation_id: carouselCreationId,
            access_token: accessToken
        });

        return {
            creationId: carouselCreationId,
            igMediaId: publishRes.data?.id
        };
    },

    /**
     * Executes the actual Meta API publishing for an InstagramPost instance
     */
    async executePublishPost(post, tenant) {
        if (!tenant) throw new Error('Tenant not found');
        const config = tenant.instagramConfig;
        if (!config || !config.connected || !config.accessToken || !config.instagramAccountId) {
            throw new Error('Instagram account is not connected on this business profile');
        }

        const igUserId = config.instagramAccountId;
        const accessToken = config.accessToken;
        const finalCaption = this.buildCaption(post.caption, post.hashtags);

        try {
            post.status = 'publishing';
            await post.save();

            let publishResult;
            if (post.mediaType === 'IMAGE') {
                const imageUrl = post.mediaUrls[0];
                publishResult = await this.publishSinglePhoto({
                    igUserId,
                    accessToken,
                    imageUrl,
                    caption: finalCaption,
                    userTags: post.userTags,
                    locationId: post.locationId
                });
            } else if (post.mediaType === 'REEL') {
                const videoUrl = post.mediaUrls[0];
                publishResult = await this.publishReel({
                    igUserId,
                    accessToken,
                    videoUrl,
                    caption: finalCaption,
                    locationId: post.locationId
                });
            } else if (post.mediaType === 'CAROUSEL') {
                publishResult = await this.publishCarousel({
                    igUserId,
                    accessToken,
                    mediaUrls: post.mediaUrls,
                    caption: finalCaption,
                    userTags: post.userTags,
                    locationId: post.locationId
                });
            } else {
                throw new Error(`Unsupported mediaType: ${post.mediaType}`);
            }

            post.status = 'published';
            post.publishedAt = new Date();
            post.creationId = publishResult.creationId || '';
            post.igMediaId = publishResult.igMediaId || '';
            post.errorMessage = '';
            await post.save();

            console.log(`[IG Publish] ✅ Post ${post._id} successfully published to Instagram! IG Media ID: ${post.igMediaId}`);
            return post;
        } catch (error) {
            console.error(`[IG Publish] ❌ Error publishing post ${post._id}:`, error.response?.data || error.message);
            const errMsg = error.response?.data?.error?.message || error.message || 'Instagram publishing failed';
            post.status = 'failed';
            post.errorMessage = errMsg;
            post.retryCount = (post.retryCount || 0) + 1;
            await post.save();
            throw new Error(errMsg);
        }
    },

    /**
     * Background worker to process scheduled posts that are due
     */
    async processDueScheduledPosts(TenantModel) {
        const now = new Date();
        const duePosts = await InstagramPost.find({
            status: 'scheduled',
            scheduledAt: { $lte: now }
        }).limit(10);

        if (!duePosts || duePosts.length === 0) {
            return;
        }

        console.log(`[IG Publish Cron] Found ${duePosts.length} due scheduled post(s) to publish...`);

        for (const post of duePosts) {
            try {
                // Find tenant
                const tenant = await TenantModel.findById(post.tenantId);
                if (!tenant || !tenant.instagramConfig?.connected) {
                    post.status = 'failed';
                    post.errorMessage = 'Tenant Instagram account is disconnected or tenant missing';
                    await post.save();
                    continue;
                }

                await this.executePublishPost(post, tenant);
            } catch (err) {
                console.error(`[IG Publish Cron] ❌ Failed to process scheduled post ${post._id}:`, err.message);
            }
        }
    }
};

module.exports = instagramPublishService;

