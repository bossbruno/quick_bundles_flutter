const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Cloud Function to send chat notifications
exports.sendChatNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    if (notification.status !== 'pending') {
      return null;
    }

    try {
      const message = {
        token: notification.recipientToken,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        android: {
          notification: {
            channelId: 'chat_notifications',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            icon: '@mipmap/ic_launcher',
            color: '#4CAF50',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'notification_sound.aiff',
              badge: 1,
              category: 'chat_message',
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      
      // Update notification status
      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });

      console.log('Successfully sent notification:', response);
      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      
      // Update notification status to failed
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw error;
    }
  });

// Cloud Function to send order status notifications
exports.sendOrderNotification = functions.firestore
  .document('chats/{chatId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if status changed
    if (before.status === after.status) {
      return null;
    }

    try {
      // Get recipient user (buyer)
      const buyerId = after.buyerId;
      const vendorId = after.vendorId;
      
      // Get buyer's FCM token
      const buyerDoc = await admin.firestore().collection('users').doc(buyerId).get();
      const buyerData = buyerDoc.data();
      const fcmToken = buyerData?.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token found for buyer:', buyerId);
        return null;
      }

      // Get bundle info
      const bundleDoc = await admin.firestore().collection('listings').doc(after.bundleId).get();
      const bundleData = bundleDoc.data();
      const bundleName = bundleData?.name || 'Data Bundle';

      // Get vendor name
      const vendorDoc = await admin.firestore().collection('users').doc(vendorId).get();
      const vendorData = vendorDoc.data();
      const vendorName = vendorData?.businessName || vendorData?.name || 'Vendor';

      let title = 'Order Update';
      let body = '';

      switch (after.status) {
        case 'processing':
          body = `Your ${bundleName} order is being processed by ${vendorName}`;
          break;
        case 'data_sent':
          body = `Your ${bundleName} has been sent successfully by ${vendorName}!`;
          break;
        case 'completed':
          body = `Your ${bundleName} order is completed`;
          break;
        default:
          body = `Your order status has been updated to ${after.status}`;
      }

      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'order_update',
          orderStatus: after.status,
          chatId: context.params.chatId,
          bundleId: after.bundleId,
        },
        android: {
          notification: {
            channelId: 'order_notifications',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            icon: '@mipmap/ic_launcher',
            color: '#2196F3',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'notification_sound.aiff',
              badge: 1,
              category: 'order_update',
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log('Successfully sent order notification:', response);
      return response;
    } catch (error) {
      console.error('Error sending order notification:', error);
      throw error;
    }
  });

// Cloud Function to clean up old notifications
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) // 7 days ago
    );

    const snapshot = await admin.firestore()
      .collection('notifications')
      .where('timestamp', '<', cutoff)
      .get();

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Cleaned up ${snapshot.docs.length} old notifications`);
  }); 