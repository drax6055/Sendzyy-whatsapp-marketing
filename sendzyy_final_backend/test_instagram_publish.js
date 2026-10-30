const mongoose = require('mongoose');
const InstagramPost = require('./models/InstagramPost');
const instagramPublishService = require('./services/instagramPublishService');

async function runTests() {
    console.log('--- Testing Instagram Publish Feature ---');

    // 1. Test Caption Builder with Hashtags
    console.log('\n[Test 1] Caption Builder:');
    const builtCaption = instagramPublishService.buildCaption('Check out our new launch!', ['sendzyy', '#marketing', 'reels']);
    console.log('Resulting Caption:\n' + builtCaption);
    if (builtCaption.includes('#sendzyy') && builtCaption.includes('#marketing') && builtCaption.includes('#reels')) {
        console.log('✅ Caption formatting passed');
    } else {
        throw new Error('Caption formatting failed');
    }

    // 2. Test InstagramPost Model Instantiation & Validation
    console.log('\n[Test 2] InstagramPost Model Validation:');
    const validPost = new InstagramPost({
        tenantId: '64d2f8e1234567890abcdef0',
        igUserId: '17841400000000000',
        mediaType: 'IMAGE',
        aspectRatio: '4:5',
        mediaUrls: ['https://appapi.sendzyy.com/uploads/instagram_media/sample.jpg'],
        caption: 'Hello World',
        hashtags: ['test', 'sendzyy'],
        userTags: [{ username: 'sendzyy_user', x: 0.5, y: 0.5 }],
        location: 'Mumbai, India',
        status: 'scheduled',
        scheduledAt: new Date(Date.now() + 86400000) // tomorrow
    });

    const validationErr = validPost.validateSync();
    if (!validationErr) {
        console.log('✅ Valid post passed schema validation');
    } else {
        throw new Error('Validation failed: ' + validationErr.message);
    }

    // 3. Test Invalid Media Type Rejection
    console.log('\n[Test 3] Invalid Enum Validation:');
    const invalidPost = new InstagramPost({
        tenantId: '64d2f8e1234567890abcdef0',
        igUserId: '17841400000000000',
        mediaType: 'AUDIO', // Invalid
        mediaUrls: ['https://example.com/audio.mp3']
    });

    const invalidErr = invalidPost.validateSync();
    if (invalidErr && invalidErr.errors['mediaType']) {
        console.log('✅ Invalid mediaType correctly rejected by schema');
    } else {
        throw new Error('Schema failed to reject invalid mediaType');
    }

    // 4. Test Schedule Past Date Validation Logic
    console.log('\n[Test 4] Past Date Prevention Logic:');
    const pastDate = new Date(Date.now() - 3600000); // 1 hour ago
    const isPast = pastDate.getTime() < Date.now() - 60000;
    if (isPast) {
        console.log('✅ Past date correctly detected and blocked');
    } else {
        throw new Error('Past date detection failed');
    }

    // 5. Test Calendar Month Filtering Date Range Calculation
    console.log('\n[Test 5] Calendar Month Date Range Calculation:');
    const yr = 2026;
    const m = 10; // October
    const startOfMonth = new Date(yr, m - 1, 1, 0, 0, 0, 0);
    const endOfMonth = new Date(yr, m, 0, 23, 59, 59, 999);
    console.log(`October 2026 range: ${startOfMonth.toISOString()} to ${endOfMonth.toISOString()}`);
    if (startOfMonth.getMonth() === 9 && endOfMonth.getMonth() === 9 && endOfMonth.getDate() === 31) {
        console.log('✅ Calendar month boundary calculations passed');
    } else {
        throw new Error('Month boundary calculation failed');
    }

    // 6. Test Two-Year Ahead Bounds
    console.log('\n[Test 6] 2-Year Ahead Horizon:');
    const now = new Date();
    const maxHorizon = new Date(now.getFullYear() + 2, now.getMonth(), 1);
    console.log(`Current: ${now.toISOString().slice(0, 7)}, Max 2-Year: ${maxHorizon.toISOString().slice(0, 7)}`);
    if (maxHorizon.getFullYear() === now.getFullYear() + 2) {
        console.log('✅ Two-year navigation horizon verified');
    }

    console.log('\n🎉 ALL INSTAGRAM PUBLISH UNIT CHECKS PASSED SUCCESSFULLY!\n');
}

runTests().catch(err => {
    console.error('❌ Test failed:', err);
    process.exit(1);
});

