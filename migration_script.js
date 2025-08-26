const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// You'll need to download your service account key from Firebase Console
// Project Settings > Service Accounts > Generate new private key
const serviceAccount = require('./path-to-your-service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateChatsToTransactions() {
  console.log('Starting migration...');
  
  try {
    // Get all existing chats
    const chatsSnapshot = await db.collection('chats').get();
    
    if (chatsSnapshot.empty) {
      console.log('No chats found to migrate.');
      return;
    }
    
    console.log(`Found ${chatsSnapshot.size} chats to migrate.`);
    
    let migratedCount = 0;
    let skippedCount = 0;
    
    for (const chatDoc of chatsSnapshot.docs) {
      const chatData = chatDoc.data();
      const chatId = chatDoc.id;
      
      console.log(`Processing chat ${chatId}...`);
      
      // Skip if already has activeOrderId
      if (chatData.activeOrderId) {
        console.log(`Chat ${chatId} already has activeOrderId, skipping...`);
        skippedCount++;
        continue;
      }
      
      // Create a transaction document for this chat
      const transactionData = {
        userId: chatData.buyerId,
        type: 'bundle_purchase',
        amount: 0, // You may want to get this from bundle data
        status: chatData.status || 'pending',
        timestamp: chatData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: chatData.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
        bundleId: chatData.bundleId,
        recipientNumber: chatData.recipientNumber,
        provider: 'unknown', // You may want to get this from bundle data
        chatId: chatId, // Reference back to the chat
      };
      
      // Add bundle-specific data if available
      if (chatData.bundleId) {
        try {
          const bundleDoc = await db.collection('bundles').doc(chatData.bundleId).get();
          if (bundleDoc.exists) {
            const bundleData = bundleDoc.data();
            transactionData.bundleName = bundleData.name;
            transactionData.dataAmount = bundleData.dataAmount;
            transactionData.validity = bundleData.validity;
            transactionData.amount = bundleData.price || 0;
          }
        } catch (error) {
          console.log(`Could not fetch bundle data for ${chatData.bundleId}: ${error.message}`);
        }
      }
      
      // Create the transaction
      const transactionRef = await db.collection('transactions').add(transactionData);
      
      // Update the chat with activeOrderId
      await db.collection('chats').doc(chatId).update({
        activeOrderId: transactionRef.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Successfully migrated chat ${chatId} with transaction ${transactionRef.id}`);
      migratedCount++;
    }
    
    console.log(`\nMigration completed!`);
    console.log(`Migrated: ${migratedCount} chats`);
    console.log(`Skipped: ${skippedCount} chats (already had activeOrderId)`);
    
  } catch (error) {
    console.error('Migration failed:', error);
  }
}

// Run the migration
migrateChatsToTransactions()
  .then(() => {
    console.log('Migration script completed.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Migration script failed:', error);
    process.exit(1);
  }); 