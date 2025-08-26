import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Notification channels for Android
  static const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
    'chat_notifications',
    'Chat Notifications',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
  );

  static const AndroidNotificationChannel _orderChannel = AndroidNotificationChannel(
    'order_notifications', 
    'Order Notifications',
    description: 'Notifications for order updates',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
  );

  /// Initialize FCM
  Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('FCM Permission granted: ${settings.authorizationStatus}');
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token and save to user document
    await _saveFCMTokenToUser();

    // Set up message handlers
    _setupMessageHandlers();

    if (kDebugMode) {
      print('FCM Service initialized successfully');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_chatChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_orderChannel);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    
    // Parse payload and navigate to appropriate screen
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final type = data['type'];
        
        if (type == 'chat_message') {
          // Navigate to chat screen
          // This would need to be implemented with a navigation service
          // or by using a global navigator key
        } else if (type == 'order_update') {
          // Navigate to order/transaction screen
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Set up FCM message handlers
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle messages when app is terminated and opened from notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleBackgroundMessage(message);
      }
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('FCM Foreground message: ${message.notification?.title}');
    }

    // Show local notification for foreground messages
    _showLocalNotification(message);
  }

  /// Handle background messages (app opened from notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('FCM Background message: ${message.notification?.title}');
    }

    // Handle navigation based on message data
    final data = message.data;
    if (data['type'] == 'chat_message') {
      // Navigate to chat screen
    } else if (data['type'] == 'order_update') {
      // Navigate to order screen
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    
    if (notification == null) return;

    // Determine which channel to use
    AndroidNotificationChannel channel = _chatChannel;
    if (data['type'] == 'order_update') {
      channel = _orderChannel;
    }

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF4CAF50),
          priority: Priority.high,
          importance: Importance.high,
          category: AndroidNotificationCategory.message,
          showWhen: true,
          when: DateTime.now().millisecondsSinceEpoch,
          autoCancel: true,
          enableVibration: true,
          playSound: true,
          sound: channel.sound,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.aiff',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  /// Get and save FCM token to user document
  Future<void> _saveFCMTokenToUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('FCM Token saved: $token');
        }
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save FCM token: $e');
      }
    }
  }

  /// Send chat message notification via FCM
  Future<void> sendChatNotification({
    required String recipientUserId,
    required String senderName,
    required String messageText,
    required String chatId,
    String? bundleInfo,
  }) async {
    try {
      // Get recipient's FCM token
      final recipientDoc = await _firestore.collection('users').doc(recipientUserId).get();
      if (!recipientDoc.exists) return;

      final fcmToken = recipientDoc.data()?['fcmToken'];
      if (fcmToken == null) {
        if (kDebugMode) {
          print('No FCM token found for user: $recipientUserId');
        }
        return;
      }

      // Send FCM message
      await _sendFCMMessage(
        token: fcmToken,
        title: senderName,
        body: messageText,
        data: {
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': _auth.currentUser?.uid ?? '',
          'senderName': senderName,
          'bundleInfo': bundleInfo ?? '',
        },
      );

      if (kDebugMode) {
        print('Chat notification sent via FCM to: $recipientUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send chat notification: $e');
      }
    }
  }

  /// Send order update notification via FCM
  Future<void> sendOrderNotification({
    required String recipientUserId,
    required String orderStatus,
    required String bundleName,
    String? chatId,
  }) async {
    try {
      // Get recipient's FCM token
      final recipientDoc = await _firestore.collection('users').doc(recipientUserId).get();
      if (!recipientDoc.exists) return;

      final fcmToken = recipientDoc.data()?['fcmToken'];
      if (fcmToken == null) return;

      String title = 'Order Update';
      String body = 'Your order status has been updated';

      switch (orderStatus) {
        case 'processing':
          body = 'Your order for $bundleName is being processed';
          break;
        case 'data_sent':
          body = 'Data has been sent for your $bundleName order';
          break;
        case 'completed':
          body = 'Your order for $bundleName has been completed';
          break;
        case 'cancelled':
          body = 'Your order for $bundleName has been cancelled';
          break;
      }

      await _sendFCMMessage(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'order_update',
          'orderStatus': orderStatus,
          'chatId': chatId ?? '',
          'bundleName': bundleName,
        },
      );

      if (kDebugMode) {
        print('Order notification sent via FCM to: $recipientUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send order notification: $e');
      }
    }
  }

  /// Send FCM message using HTTP API
  Future<void> _sendFCMMessage({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      // Note: You'll need to get your server key from Firebase Console
      // Go to Project Settings > Cloud Messaging > Server key
      const String serverKey = 'YOUR_FCM_SERVER_KEY_HERE';
      
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
            'badge': '1',
          },
          'data': data,
          'priority': 'high',
          'content_available': true,
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('FCM message sent successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to send FCM message: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending FCM message: $e');
      }
    }
  }

  /// Get current user's FCM token
  Future<String?> getCurrentToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to delete FCM token: $e');
      }
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Background message: ${message.notification?.title}');
  }
  
  // Handle background message processing here
  // This runs even when the app is terminated
}
