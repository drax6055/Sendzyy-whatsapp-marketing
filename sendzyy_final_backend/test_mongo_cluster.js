const dns = require('dns');
// Set public DNS servers to resolve MongoDB SRV records reliably in Node on Windows
dns.setServers(['8.8.8.8', '1.1.1.1']);

const mongoose = require('mongoose');

const rawUri = "mongodb+srv://iiplitdepartment_db_user:5qK8nUve5HrHza#@whatsappbulk.pnmc7cp.mongodb.net/";
const encodedUri = "mongodb+srv://iiplitdepartment_db_user:5qK8nUve5HrHza%23@whatsappbulk.pnmc7cp.mongodb.net/";
const directReplicaUri = "mongodb://iiplitdepartment_db_user:5qK8nUve5HrHza%23@ac-qwofnui-shard-00-00.pnmc7cp.mongodb.net:27017,ac-qwofnui-shard-00-01.pnmc7cp.mongodb.net:27017,ac-qwofnui-shard-00-02.pnmc7cp.mongodb.net:27017/?ssl=true&authSource=admin&retryWrites=true&w=majority";

async function tryConnect(uri, label) {
  console.log(`\n========================================`);
  console.log(`Attempting connection with ${label}...`);
  console.log(`URI: ${uri.replace(/:([^:@]+)@/, ':****@')}`);
  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 10000,
    });
    console.log(`>>> Connection SUCCESSFUL with ${label}!`);
    return conn;
  } catch (err) {
    console.error(`>>> Connection FAILED with ${label}:`, err.message);
    return null;
  }
}

async function inspectCluster(connection) {
  try {
    const adminDb = connection.connection.db.admin();
    const dbsInfo = await adminDb.listDatabases();
    console.log('\n--- DATABASES IN CLUSTER ---');
    console.log(JSON.stringify(dbsInfo.databases, null, 2));

    const skipDbs = ['admin', 'config', 'local'];

    for (const dbInfo of dbsInfo.databases) {
      const dbName = dbInfo.name;
      if (skipDbs.includes(dbName)) {
        console.log(`\nSkipping system database: [${dbName}]`);
        continue;
      }

      console.log(`\n========================================`);
      console.log(`Database: [${dbName}] (size: ${dbInfo.sizeOnDisk} bytes)`);
      
      const targetDb = connection.connection.useDb(dbName);
      const collections = await targetDb.db.listCollections().toArray();
      
      if (collections.length === 0) {
        console.log(`  (No collections found in ${dbName})`);
        continue;
      }

      for (const col of collections) {
        const colName = col.name;
        try {
          const count = await targetDb.db.collection(colName).countDocuments();
          console.log(`  Collection: [${colName}] - Count: ${count}`);
          
          if (count > 0 && count <= 5) {
            const docs = await targetDb.db.collection(colName).find().toArray();
            console.log(`    Documents:`);
            console.log(JSON.stringify(docs, null, 2).split('\n').map(l => '      ' + l).join('\n'));
          } else if (count > 5) {
            const sample = await targetDb.db.collection(colName).find().limit(2).toArray();
            console.log(`    Sample documents (2 of ${count}):`);
            console.log(JSON.stringify(sample, null, 2).split('\n').map(l => '      ' + l).join('\n'));
          }
        } catch (colErr) {
          console.log(`  Collection: [${colName}] - Error reading: ${colErr.message}`);
        }
      }
    }
  } catch (err) {
    console.error('Error during cluster inspection:', err);
  } finally {
    await mongoose.disconnect();
    console.log('\nDisconnected from MongoDB.');
  }
}

async function run() {
  let conn = await tryConnect(rawUri, 'Raw URI (with literal #)');
  if (!conn) {
    console.log('\nTrying URI with URL-encoded password (# -> %23)...');
    conn = await tryConnect(encodedUri, 'URL-encoded password URI');
  }
  if (!conn) {
    console.log('\nTrying Direct Replica Set URI...');
    conn = await tryConnect(directReplicaUri, 'Direct Shard Nodes URI');
  }

  if (conn) {
    await inspectCluster(conn);
  } else {
    console.error('\nCould not connect with either URI format. Check network, IP whitelisting (Atlas 0.0.0.0/0), or user credentials.');
  }
}

run();
