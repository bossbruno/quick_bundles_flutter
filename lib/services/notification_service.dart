import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'shared_preference_service.dart';
import 'package:flutter/material.dart';
import 'onesignal_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Notification channels for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chat_notifications',
    'Chat Notifications',
    description: 'Notifications for chat messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _orderChannel = AndroidNotificationChannel(
    'order_notifications',
    'Order Notifications',
    description: 'Notifications for order updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    try {
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
        print('User granted permission: ${settings.authorizationStatus}');
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Ensure iOS foreground notifications are presented (alert, badge, sound)
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((message) => handleForegroundMessage(message));

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      if (kDebugMode) {
        print('Notification service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize notification service: $e');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'chat_messages',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.text(
              'reply',
              'Reply',
              buttonTitle: 'Reply',
              placeholder: 'Type your reply...',
            ),
          ],
        ),
      ],
    );

    final InitializationSettings initializationSettings = InitializationSettings(
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
        ?.createNotificationChannel(_channel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_orderChannel);
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('FCM token saved to database');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save FCM token: $e');
      }
    }
  }

  // Save OneSignal player ID to database
  Future<void> saveOneSignalPlayerId() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        String? playerId = await OneSignalService.getCurrentPlayerId();
        if (playerId != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'oneSignalPlayerId': playerId,
            'lastOneSignalUpdate': FieldValue.serverTimestamp(),
          });
          if (kDebugMode) {
            print('OneSignal player ID saved to database: $playerId');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save OneSignal player ID: $e');
      }
    }
  }

  @visibleForTesting
  Future<void> handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      print('Message notification: ${message.notification}');
    }

    // Check if the message is from FCM or OneSignal
    final isFromFCM = message.data.isNotEmpty;
    
    if (isFromFCM) {
      // Handle FCM message
      if (message.notification != null) {
        if (kDebugMode) {
          print('FCM Notification: ${message.notification!.title} - ${message.notification!.body}');
        }
        // Show local notification for FCM
        await _showLocalNotification(message);
      }
    } else {
      // Handle OneSignal message
      if (message.notification != null) {
        if (kDebugMode) {
          print('OneSignal Notification: ${message.notification!.title} - ${message.notification!.body}');
        }
        // Show local notification for OneSignal
        await _showLocalNotification(message);
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      // Android notification details
      final androidDetails = android != null
          ? AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
              color: const Color(0xFF4CAF50), // Green color for chat
              priority: Priority.high,
              importance: Importance.high,
              category: AndroidNotificationCategory.message,
              showWhen: true,
              when: DateTime.now().millisecondsSinceEpoch,
              autoCancel: true,
              enableVibration: true,
              playSound: true,
              sound: const RawResourceAndroidNotificationSound('notification_sound'),
            )
          : null;

      // iOS notification details
      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'slow_spring_board.aiff',
        badgeNumber: 1,
        threadIdentifier: 'chat-messages',
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // Handle notification tap - navigate to appropriate screen
    _handleNotificationTap(response.payload);
  }

  void _handleNotificationTap(String? payload) {
    // This will be implemented to navigate to the appropriate chat screen
    if (kDebugMode) {
      print('Notification tapped with payload: $payload');
    }
  }

  // Handler for notification taps from background
  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification opened from background: ${message.data}');
    }
    // If you use a payload key, extract it; otherwise, pass the whole data map or adjust as needed
    _handleNotificationTap(message.data['payload']);
  }

  // Public method to show a local chat notification (for direct triggers)
  Future<void> showLocalChatNotification({
    required String title, 
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
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
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Method to send chat notification to specific user using OneSignal
  Future<void> sendChatNotification({
    required String recipientUserId,
    required String senderName,
    required String message,
    required String chatId,
    String? bundleId,
  }) async {
    try {
      // Check user's notification preferences
      final userPreferences = await getNotificationPreferences();
      if (!(userPreferences['chatNotifications'] ?? true)) {
        if (kDebugMode) {
          print('Chat notifications disabled for user: $recipientUserId');
        }
        return;
      }

      // Get recipient's OneSignal player ID
      final recipientDoc = await _firestore.collection('users').doc(recipientUserId).get();
      final recipientData = recipientDoc.data();
      final oneSignalPlayerId = recipientData?['oneSignalPlayerId'];

      if (oneSignalPlayerId == null) {
        if (kDebugMode) {
          print('No OneSignal player ID found for user: $recipientUserId');
        }
        return;
      }

      // Send notification via OneSignal
      await OneSignalService.sendChatNotification(
        playerId: oneSignalPlayerId,
        message: message.length > 50 ? '${message.substring(0, 50)}...' : message,
        senderName: senderName,
        chatId: chatId,
      );

      if (kDebugMode) {
        print('Chat notification sent via OneSignal to user: $recipientUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send chat notification: $e');
      }
    }
  }

  // Method to send order status notification using OneSignal
  Future<void> sendOrderNotification({
    required String recipientUserId,
    required String orderStatus,
    required String bundleName,
    String? chatId,
  }) async {
    try {
      // Check user's notification preferences
      final userPreferences = await getNotificationPreferences();
      if (!(userPreferences['orderNotifications'] ?? true)) {
        if (kDebugMode) {
          print('Order notifications disabled for user: $recipientUserId');
        }
        return;
      }

      // Get recipient's OneSignal player ID
      final recipientDoc = await _firestore.collection('users').doc(recipientUserId).get();
      final recipientData = recipientDoc.data();
      final oneSignalPlayerId = recipientData?['oneSignalPlayerId'];

      if (oneSignalPlayerId == null) {
        if (kDebugMode) {
          print('No OneSignal player ID found for user: $recipientUserId');
        }
        return;
      }

      String title = 'Order Update';
      String body = '';

      switch (orderStatus) {
        case 'processing':
          body = 'Your $bundleName order is being processed';
          break;
        case 'data_sent':
          body = 'Your $bundleName has been sent successfully!';
          break;
        case 'completed':
          body = 'Your $bundleName order is completed';
          break;
        default:
          body = 'Your order status has been updated';
      }

      // Send notification via OneSignal
      await OneSignalService.sendNotification(
        playerId: oneSignalPlayerId,
        title: title,
        message: body,
        additionalData: {
          'type': 'order_update',
          'orderStatus': orderStatus,
          'chatId': chatId,
          'bundleName': bundleName,
        },
      );

      if (kDebugMode) {
        print('Order notification sent via OneSignal to user: $recipientUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send order notification: $e');
      }
    }
  }

  // Method to update user's notification preferences
  Future<void> updateNotificationPreferences({
    required bool chatNotifications,
    required bool orderNotifications,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'notificationPreferences': {
            'chatNotifications': chatNotifications,
            'orderNotifications': orderNotifications,
          },
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update notification preferences: $e');
      }
    }
  }

  // Method to get user's notification preferences
  Future<Map<String, bool>> getNotificationPreferences() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        final data = doc.data();
        final preferences = data?['notificationPreferences'] as Map<String, dynamic>?;
        
        return {
          'chatNotifications': preferences?['chatNotifications'] ?? true,
          'orderNotifications': preferences?['orderNotifications'] ?? true,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get notification preferences: $e');
      }
    }
    
    return {
      'chatNotifications': true,
      'orderNotifications': true,
    };
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  try {
    await Firebase.initializeApp();
    
    // Initialize GetX
    Get.put(GetMaterialController(), permanent: true);
    
    // Initialize Shared Preferences
    final sharedPrefs = BambooSharedPreference();
    await sharedPrefs.init();
    Get.put<BambooSharedPreference>(sharedPrefs, permanent: true);
    
    // Initialize notifications
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    // Handle the notification
    if (message.notification != null) {
      await notificationService._showLocalNotification(message);
    }
    
  } catch (e, stack) {
    if (kDebugMode) {
      print('Error in background handler: $e');
      print('Stack trace: $stack');
    }
  }
  
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}