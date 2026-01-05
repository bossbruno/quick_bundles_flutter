const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Email configuration - UPDATE THE PASSWORD BELOW
function _getTransporter() {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: 'kwakye105@gmail.com',
      pass: process.env.GMAIL_APP_PASSWORD,
    },
  });
}

const DELETE_AFTER_DAYS = 7;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

exports.deleteUnverifiedUsers = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('Africa/Accra')
  .onRun(async () => {
    const now = Date.now();
    const cutoffTime = now - (DELETE_AFTER_DAYS * MS_PER_DAY);

    try {
      const listUsersResult = await admin.auth().listUsers(1000);
      const users = listUsersResult.users;

      const deletePromises = [];

      for (const user of users) {
        if (user.emailVerified) continue;

        const userDoc = await admin.firestore().collection('users').doc(user.uid).get();

        if (!userDoc.exists || (userDoc.data()?.emailVerified === true)) continue;

        const userCreationTime = user.metadata.creationTime ? new Date(user.metadata.creationTime).getTime() : now;

        if (userCreationTime < cutoffTime) {
          deletePromises.push(
            admin
              .auth()
              .deleteUser(user.uid)
              .then(() => admin.firestore().collection('users').doc(user.uid).delete())
              .catch((error) => console.error(`Error deleting user ${user.uid}:`, error)),
          );
        }
      }

      await Promise.all(deletePromises);
      return null;
    } catch (error) {
      console.error('Error in deleteUnverifiedUsers:', error);
      return null;
    }
  });

exports.sendVerificationReminder = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('Africa/Accra')
  .onRun(async () => {
    const now = Date.now();
    const oneDayAgo = now - MS_PER_DAY;

    try {
      const listUsersResult = await admin.auth().listUsers(1000);
      const users = listUsersResult.users;

      for (const user of users) {
        if (user.emailVerified) continue;

        const userDoc = await admin.firestore().collection('users').doc(user.uid).get();

        if (
          !userDoc.exists ||
          userDoc.data()?.emailVerified === true ||
          userDoc.data()?.verificationReminderSent === true
        ) {
          continue;
        }

        const userCreationTime = user.metadata.creationTime ? new Date(user.metadata.creationTime).getTime() : now;

        if (userCreationTime < oneDayAgo) {
          try {
            await admin.auth().generateEmailVerificationLink(user.email);

            await admin.firestore().collection('users').doc(user.uid).update({
              verificationReminderSent: true,
              lastVerificationReminder: admin.firestore.FieldValue.serverTimestamp(),
            });
          } catch (error) {
            console.error(`Error sending verification reminder to ${user.email}:`, error);
          }
        }
      }

      return null;
    } catch (error) {
      console.error('Error in sendVerificationReminder:', error);
      return null;
    }
  });

async function _getUserFcmToken(userId) {
  const doc = await admin.firestore().collection('users').doc(userId).get();
  const data = doc.data();
  const token = data?.fcmToken;
  if (typeof token === 'string' && token.trim().length > 0) return token.trim();
  return null;
}

async function _sendToUser(userId, message) {
  const token = await _getUserFcmToken(userId);
  if (!token) return null;
  try {
    return await admin.messaging().send({
      token,
      ...message,
    });
  } catch (error) {
    console.error('Error sending FCM:', error);
    if (error?.code === 'messaging/registration-token-not-registered') {
      try {
        await admin.firestore().collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      } catch (e) {
        console.error('Failed to clear invalid FCM token:', e);
      }
    }
    return null;
  }
}

exports.notifyOnNewChatMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const msg = snap.data();
    const senderId = msg?.senderId;
    const isSystem = msg?.isSystem === true;

    if (!senderId || typeof senderId !== 'string') return null;
    if (isSystem) return null;

    const chatId = context.params.chatId;
    const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return null;

    const chat = chatDoc.data();
    const buyerId = chat?.buyerId;
    const vendorId = chat?.vendorId;
    const bundleId = chat?.bundleId || '';

    if (!buyerId || !vendorId) return null;

    const recipientId = senderId === buyerId ? vendorId : buyerId;

    let senderName = 'New message';
    if (senderId === buyerId) {
      senderName = chat?.buyerName || 'Buyer';
    } else {
      const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
      const senderData = senderDoc.data();
      senderName = senderData?.businessName || senderData?.name || 'Vendor';
    }

    const text = (msg?.text || '').toString().trim();
    const imageUrl = (msg?.imageUrl || '').toString().trim();
    const body = imageUrl && !text ? '📷 Image' : (text ? text : 'New message');

    const payload = {
      notification: {
        title: `New message from ${senderName}`,
        body: body.length > 160 ? `${body.substring(0, 160)}...` : body,
      },
      data: {
        type: 'chat',
        chatId,
        bundleId: bundleId.toString(),
        senderId,
      },
      android: {
        notification: {
          channelId: 'chat_notifications',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    return await _sendToUser(recipientId.toString(), payload);
  });

exports.notifyOnNewOrderChat = functions.firestore
  .document('chats/{chatId}')
  .onCreate(async (snap, context) => {
    const chat = snap.data();
    const vendorId = chat?.vendorId;
    const buyerId = chat?.buyerId;
    const buyerName = chat?.buyerName || 'Buyer';
    const bundleId = chat?.bundleId;
    const recipientNumber = (chat?.recipientNumber || '').toString();

    if (!vendorId || !buyerId) return null;

    let bundleName = 'Bundle';
    if (bundleId) {
      try {
        const bundleDoc = await admin.firestore().collection('listings').doc(bundleId.toString()).get();
        const bundleData = bundleDoc.data();
        bundleName = bundleData?.description || bundleData?.title || bundleData?.name || bundleName;
      } catch (_) {
        bundleName = bundleName;
      }
    }

    const body = recipientNumber ? `${bundleName} for ${recipientNumber}` : `${bundleName}`;

    const payload = {
      notification: {
        title: `New order from ${buyerName}`,
        body: body.length > 160 ? `${body.substring(0, 160)}...` : body,
      },
      data: {
        type: 'order_update',
        orderStatus: (chat?.status || 'pending').toString(),
        chatId: context.params.chatId,
        bundleId: (bundleId || '').toString(),
        buyerId: buyerId.toString(),
      },
      android: {
        notification: {
          channelId: 'order_notifications',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    return await _sendToUser(vendorId.toString(), payload);
  });

// Function to send email notifications for new reports
exports.sendReportNotification = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    const report = snap.data();
    
    try {
      // Get reporter details
      const reporterDoc = await admin.firestore().collection('users').doc(report.reporterId).get();
      const reporterData = reporterDoc.data();
      
      // Get vendor details
      const vendorDoc = await admin.firestore().collection('users').doc(report.vendorId).get();
      const vendorData = vendorDoc.data();
      
      // Get buyer details
      const buyerDoc = await admin.firestore().collection('users').doc(report.buyerId).get();
      const buyerData = buyerDoc.data();
      
      const emailContent = `
        <h2>🚨 New Report Submitted</h2>
        
        <h3>Report Details:</h3>
        <p><strong>Reason:</strong> ${report.reason}</p>
        <p><strong>Description:</strong> ${report.description}</p>
        <p><strong>Status:</strong> ${report.status}</p>
        <p><strong>Reporter Type:</strong> ${report.reporterType}</p>
        
        <h3>Chat Information:</h3>
        <p><strong>Chat ID:</strong> ${report.chatId}</p>
        <p><strong>Chat Status:</strong> ${report.chatStatus}</p>
        
        <h3>Bundle Details:</h3>
        <p><strong>Data Amount:</strong> ${report.bundleDetails.dataAmount}GB</p>
        <p><strong>Provider:</strong> ${report.bundleDetails.provider}</p>
        <p><strong>Price:</strong> GHS${report.bundleDetails.price}</p>
        
        <h3>User Information:</h3>
        <p><strong>Reporter:</strong> ${reporterData?.name || reporterData?.businessName || 'Unknown'} (${reporterData?.email || 'No email'})</p>
        <p><strong>Vendor:</strong> ${vendorData?.name || vendorData?.businessName || 'Unknown'} (${vendorData?.email || 'No email'})</p>
        <p><strong>Buyer:</strong> ${buyerData?.name || buyerData?.businessName || 'Unknown'} (${buyerData?.email || 'No email'})</p>
        
        <h3>Recent Messages:</h3>
        ${report.recentMessages.map(msg => `
          <div style="margin: 8px 0; padding: 8px; background: #f5f5f5; border-radius: 4px;">
            <strong>${msg.senderId === 'system' ? 'System' : msg.senderId}:</strong> ${msg.text}
            <br><small>${msg.timestamp ? new Date(msg.timestamp.toDate()).toLocaleString() : 'No timestamp'}</small>
          </div>
        `).join('')}
        
        <hr>
        <p><em>Report submitted at: ${new Date().toLocaleString()}</em></p>
        <p><em>Report ID: ${context.params.reportId}</em></p>
      `;
      
      const mailOptions = {
        from: 'kwakye105@gmail.com',
        to: 'kwakye105@gmail.com',
        subject: `🚨 Quick Bundles Report: ${report.reason}`,
        html: emailContent,
      };
      
      await _getTransporter().sendMail(mailOptions);
      
      console.log('Report notification email sent successfully');
      
      // Update the report with email sent status
      await snap.ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
    } catch (error) {
      console.error('Error sending report notification email:', error);
      
      // Update the report with email error status
      await snap.ref.update({
        emailError: error.message,
        emailErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

// Function to send email notifications for report status updates
exports.sendReportStatusUpdate = functions.firestore
  .document('reports/{reportId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Only send email if status changed
    if (before.status === after.status) return;
    
    try {
      const report = after;
      
      const emailContent = `
        <h2>📊 Report Status Updated</h2>
        
        <h3>Report Details:</h3>
        <p><strong>Reason:</strong> ${report.reason}</p>
        <p><strong>Previous Status:</strong> ${before.status}</p>
        <p><strong>New Status:</strong> ${report.status}</p>
        
        ${report.adminNotes ? `<p><strong>Admin Notes:</strong> ${report.adminNotes}</p>` : ''}
        
        <h3>Chat Information:</h3>
        <p><strong>Chat ID:</strong> ${report.chatId}</p>
        <p><strong>Bundle:</strong> ${report.bundleDetails.dataAmount}GB ${report.bundleDetails.provider}</p>
        
        <hr>
        <p><em>Status updated at: ${new Date().toLocaleString()}</em></p>
        <p><em>Report ID: ${context.params.reportId}</em></p>
      `;
      
      const mailOptions = {
        from: 'kwakye105@gmail.com',
        to: 'kwakye105@gmail.com',
        subject: `📊 Quick Bundles Report Status: ${report.status.toUpperCase()}`,
        html: emailContent,
      };
      
      await _getTransporter().sendMail(mailOptions);
      
      console.log('Report status update email sent successfully');
      
    } catch (error) {
      console.error('Error sending report status update email:', error);
    }
  });

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