const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// Set dummy JWT secret for test
process.env.JWT_SECRET = 'test-secret-key-999';

async function runTests() {
    console.log('=== Starting Multi-Tier Employee & Chat Isolation Tests ===');
    const mongod = await MongoMemoryServer.create();
    const uri = mongod.getUri();
    await mongoose.connect(uri);

    // 1. Models
    const Employee = require('./models/Employee');
    const tenantSchema = new mongoose.Schema({
        name: String,
        email: { type: String, unique: true },
        password: String,
        subscription: { planId: String, expiryDate: Date },
        whatsappConfig: Object,
        status: { type: String, default: 'active' }
    });
    const Tenant = mongoose.model('Tenant', tenantSchema);

    const conversationSchema = new mongoose.Schema({
        tenantId: String,
        contactId: String,
        name: String,
        lastMessage: String,
        lastActive: { type: Date, default: Date.now },
        hasReply: { type: Boolean, default: false },
        assignedTo: { type: String, default: null },
        assignedToName: { type: String, default: null },
        assignedAt: { type: Date, default: null },
        assignedBy: { type: String, default: null },
    });
    const Conversation = mongoose.model('Conversation', conversationSchema);

    const messageSchema = new mongoose.Schema({
        tenantId: String,
        contactId: String,
        text: String,
        isMe: Boolean,
        senderId: String,
        senderName: String,
        time: String,
    });
    const Message = mongoose.model('Message', messageSchema);

    // Setup Tenant
    const tenantPasswordHash = await bcrypt.hash('masterpass123', 10);
    const tenant = await Tenant.create({
        name: 'Acme Corp Master',
        email: 'admin@acmecorp.com',
        password: tenantPasswordHash,
        subscription: {
            planId: 'panel_12m',
            expiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        },
        whatsappConfig: {
            phoneNumberId: 'phone_12345',
            accessToken: 'meta_access_token_abc'
        },
        status: 'active'
    });
    console.log('✔ Master Tenant created:', tenant.name);

    // TEST 1: Create Employee with specific permissions
    const emp1PassHash = await bcrypt.hash('emp1pass123', 10);
    const employee1 = await Employee.create({
        tenantId: tenant._id.toString(),
        name: 'Alice Agent',
        email: 'alice@acmecorp.com',
        password: emp1PassHash,
        permissions: ['chat', 'broadcast'],
        status: 'active'
    });
    console.log('✔ Employee 1 created with permissions:', employee1.permissions);

    const emp2PassHash = await bcrypt.hash('emp2pass123', 10);
    const employee2 = await Employee.create({
        tenantId: tenant._id.toString(),
        name: 'Bob Agent',
        email: 'bob@acmecorp.com',
        password: emp2PassHash,
        permissions: ['chat', 'leads', 'templates'],
        status: 'active'
    });
    console.log('✔ Employee 2 created with permissions:', employee2.permissions);

    // TEST 2: Validate Employee login authentication
    const isEmp1PassCorrect = await bcrypt.compare('emp1pass123', employee1.password);
    if (!isEmp1PassCorrect) throw new Error('Employee 1 password verification failed');
    console.log('✔ Employee password verification passed');

    // TEST 3: Generate JWT for Employee 1
    const token = jwt.sign({
        tenantId: tenant._id.toString(),
        employeeId: employee1._id.toString(),
        email: employee1.email,
        name: employee1.name,
        role: 'employee',
        permissions: employee1.permissions
    }, process.env.JWT_SECRET);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.role !== 'employee' || decoded.employeeId !== employee1._id.toString()) {
        throw new Error('JWT payload mismatch');
    }
    console.log('✔ Employee JWT signed and verified with role: employee and employeeId');

    // TEST 4: Chat Isolation - Sending message binds contact to Employee 1
    const contactA = '919876543210';
    const contactB = '919876543211';

    // Alice messages Contact A -> binds to Alice
    await Conversation.create({
        tenantId: tenant._id.toString(),
        contactId: contactA,
        name: 'Customer A',
        lastMessage: 'Hello from Alice',
        assignedTo: employee1._id.toString(),
        assignedToName: employee1.name,
        assignedAt: new Date(),
        assignedBy: 'auto'
    });

    // Bob messages Contact B -> binds to Bob
    await Conversation.create({
        tenantId: tenant._id.toString(),
        contactId: contactB,
        name: 'Customer B',
        lastMessage: 'Hello from Bob',
        assignedTo: employee2._id.toString(),
        assignedToName: employee2.name,
        assignedAt: new Date(),
        assignedBy: 'auto'
    });

    // Unassigned Contact C
    await Conversation.create({
        tenantId: tenant._id.toString(),
        contactId: '919876543212',
        name: 'Customer C',
        lastMessage: 'Inbound enquiry',
        assignedTo: null,
        assignedToName: null
    });

    // Query as Alice: should only see Contact A
    const aliceChats = await Conversation.find({
        tenantId: tenant._id.toString(),
        assignedTo: employee1._id.toString()
    });
    if (aliceChats.length !== 1 || aliceChats[0].contactId !== contactA) {
        throw new Error(`Alice should only see Contact A, got ${aliceChats.length} chats`);
    }
    console.log('✔ Chat Isolation: Alice only sees her assigned chat (Contact A)');

    // Query as Bob: should only see Contact B
    const bobChats = await Conversation.find({
        tenantId: tenant._id.toString(),
        assignedTo: employee2._id.toString()
    });
    if (bobChats.length !== 1 || bobChats[0].contactId !== contactB) {
        throw new Error(`Bob should only see Contact B, got ${bobChats.length} chats`);
    }
    console.log('✔ Chat Isolation: Bob only sees his assigned chat (Contact B)');

    // Query as Master Tenant Super-Admin: can see ALL chats (3)
    const allChats = await Conversation.find({ tenantId: tenant._id.toString() });
    if (allChats.length !== 3) {
        throw new Error(`Master Tenant should see all 3 chats, got ${allChats.length}`);
    }
    console.log('✔ Master Tenant Admin sees all 3 chats across organization');

    // Admin filters unassigned chats: should only see Customer C
    const unassignedChats = await Conversation.find({
        tenantId: tenant._id.toString(),
        $or: [{ assignedTo: null }, { assignedTo: { $exists: false } }, { assignedTo: '' }]
    });
    if (unassignedChats.length !== 1 || unassignedChats[0].contactId !== '919876543212') {
        throw new Error('Unassigned filter failed');
    }
    console.log('✔ Master Tenant Admin filtered unassigned chats successfully');

    // TEST 5: Admin reassigns Contact A from Alice to Bob
    await Conversation.findOneAndUpdate(
        { tenantId: tenant._id.toString(), contactId: contactA },
        {
            assignedTo: employee2._id.toString(),
            assignedToName: employee2.name,
            assignedAt: new Date(),
            assignedBy: 'admin'
        }
    );
    const updatedBobChats = await Conversation.find({
        tenantId: tenant._id.toString(),
        assignedTo: employee2._id.toString()
    });
    if (updatedBobChats.length !== 2) {
        throw new Error(`Bob should now have 2 chats after reassignment, got ${updatedBobChats.length}`);
    }
    console.log('✔ Admin reassigns chat from Alice to Bob successfully');

    // TEST 6: Isolation barrier - check if Alice attempts to message contact now assigned to Bob
    const checkConv = await Conversation.findOne({ tenantId: tenant._id.toString(), contactId: contactA });
    const isAllowedForAlice = !checkConv.assignedTo || checkConv.assignedTo === employee1._id.toString();
    if (isAllowedForAlice) {
        throw new Error('Isolation barrier failed: Alice was allowed to access Bob contact');
    }
    console.log('✔ Isolation barrier: Alice blocked from messaging Bob assigned contact');

    await mongoose.disconnect();
    await mongod.stop();
    console.log('\n🎉 ALL MULTI-TIER EMPLOYEE & CHAT ISOLATION TESTS PASSED!');
}

runTests().catch(err => {
    console.error('❌ Test failed:', err);
    process.exit(1);
});
