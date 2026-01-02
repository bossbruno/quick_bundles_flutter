import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'shared_preference_service.dart';
import 'package:flutter/material.dart';
import 'onesignal_service.dart';
import 'fcm_service.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/chat/screens/vendor_chat_detail_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Global navigator key for deep-link navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track chat message listeners and last notified message per chat to avoid duplicates
  final Map<String, StreamSubscription<QuerySnapshot>> _chatMessageSubs = {};
  final Map<String, String> _lastNotifiedMessageId = {};

  StreamSubscription<User?>? _authStateSub;
  StreamSubscription<QuerySnapshot>? _buyerChatsSub;
  StreamSubscription<QuerySnapshot>? _vendorChatsSub;

  bool _buyerChatsLoaded = false;
  bool _vendorChatsLoaded = false;
  String? _localListenersUserId;
  final Map<String, String> _lastNotifiedChatStatus = {};
  bool _initialized = false;

  // Notification channels for Android
  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'quick_bundles_notifications',
    'General Notifications',
    description: 'Default notifications channel',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
  );
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
      if (_initialized) return;
      _initialized = true;

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

  // Local notifications fallback: watch chats the user participates in and notify on new incoming messages
  Future<void> _startChatLocalNotificationListeners() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    if (_localListenersUserId != null && _localListenersUserId == userId) {
      return;
    }

    await _stopChatLocalNotificationListeners();
    _localListenersUserId = userId;
    _buyerChatsLoaded = false;
    _vendorChatsLoaded = false;

    // Helper to attach a messages listener for a chat
    Future<void> _attachForChat(String chatId, String otherPartyName) async {
      if (_chatMessageSubs.containsKey(chatId)) return;
      final sub = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.docs.isEmpty) return;
        final doc = snapshot.docs.first;
        final data = doc.data();
        final senderId = data['senderId']?.toString();
        final text = (data['text']?.toString() ?? '').trim();
        final imageUrl = data['imageUrl']?.toString();
        final messageId = doc.id;

        // Prime last message id on first attach to avoid notifying on historical messages
        if (!_lastNotifiedMessageId.containsKey(chatId)) {
          _lastNotifiedMessageId[chatId] = messageId;
          return;
        }

        // Ignore if from self or already notified
        if (senderId == userId) return;
        if (senderId == null || senderId.isEmpty || senderId == 'system') return;
        if (_lastNotifiedMessageId[chatId] == messageId) return;
        _lastNotifiedMessageId[chatId] = messageId;

        // Show local notification
        final body = (imageUrl != null && imageUrl.isNotEmpty) ? '📷 Image' : (text.isNotEmpty ? text : 'New message');
        await showLocalChatNotification(
          title: 'New message from $otherPartyName',
          body: body,
          // Pass a JSON payload so tap can deep-link to the chat
          payload: jsonEncode({
            'type': 'chat',
            'chatId': chatId,
          }),
        );
      });
      _chatMessageSubs[chatId] = sub;
    }

    // Listen to chats where user is buyer
    _buyerChatsSub = _firestore
        .collection('chats')
        .where('buyerId', isEqualTo: userId)
        .snapshots()
        .listen((snap) async {
      if (!_buyerChatsLoaded) {
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'pending').toString();
          _lastNotifiedChatStatus[doc.id] = status;
        }
        _buyerChatsLoaded = true;
      }

      if (_buyerChatsLoaded) {
        for (final change in snap.docChanges) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final status = (data['status'] ?? 'pending').toString();
          final prev = _lastNotifiedChatStatus[change.doc.id];
          _lastNotifiedChatStatus[change.doc.id] = status;

          if (change.type == DocumentChangeType.modified && prev != null && prev != status) {
            await showLocalOrderNotification(
              title: 'Order update',
              body: 'Status: ${status.replaceAll('_', ' ').toUpperCase()}',
              payload: jsonEncode({
                'type': 'order',
                'chatId': change.doc.id,
              }),
            );
          }
        }
      }

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vendorId = data['vendorId']?.toString();
        String otherName = 'Vendor';
        try {
          if (vendorId != null) {
            final vd = await _firestore.collection('users').doc(vendorId).get();
            final vdata = vd.data();
            otherName = (vdata?['businessName'] ?? vdata?['name'] ?? 'Vendor').toString();
          }
        } catch (_) {}
        await _attachForChat(doc.id, otherName);
      }
    });

    // Listen to chats where user is vendor
    _vendorChatsSub = _firestore
        .collection('chats')
        .where('vendorId', isEqualTo: userId)
        .where('status', isNotEqualTo: 'completed')  // Exclude completed chats
        .snapshots()
        .listen((snap) async {
      if (!_vendorChatsLoaded) {
        // Initial load - track existing chat IDs but don't notify
        for (final doc in snap.docs) {
          _lastNotifiedChatStatus[doc.id] = (doc.data()['status'] ?? 'pending').toString();
        }
        _vendorChatsLoaded = true;
      } else {
        // Only notify for newly added chats
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          
          // Skip if this is a completed chat
          final status = (data['status'] ?? 'pending').toString();
          if (status == 'completed') continue;
          
          final buyerName = (data['buyerName'] ?? 'Buyer').toString();
          final lastMessage = (data['lastMessage'] ?? 'New order started').toString();
          await showLocalOrderNotification(
            title: 'New order from $buyerName',
            body: lastMessage,
            payload: jsonEncode({
              'type': 'order',
              'chatId': change.doc.id,
            }),
          );
        }
      }

      // Attach message listeners only for non-completed chats
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? 'pending').toString();
        if (status == 'completed') continue; // Skip completed chats
        
        final buyerId = data['buyerId']?.toString();
        String otherName = 'Buyer';
        try {
          if (buyerId != null) {
            final bd = await _firestore.collection('users').doc(buyerId).get();
            final bdata = bd.data();
            otherName = (bdata?['name'] ?? 'Buyer').toString();
          }
        } catch (_) {}
        await _attachForChat(doc.id, otherName);
      }
    });
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
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      if (kDebugMode) {
        print('Notification service initialized successfully');
      }

      // Start local notification listeners for chat messages as a fallback when remote push is unavailable
      _startChatLocalNotificationListeners();

      _authStateSub ??= _auth.authStateChanges().listen((user) async {
        if (user == null) {
          await _stopChatLocalNotificationListeners();
        } else {
          await _startChatLocalNotificationListeners();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize notification service: $e');
      }
    }
  }

  Future<void> _stopChatLocalNotificationListeners() async {
    try {
      await _buyerChatsSub?.cancel();
      await _vendorChatsSub?.cancel();
      _buyerChatsSub = null;
      _vendorChatsSub = null;

      for (final sub in _chatMessageSubs.values) {
        await sub.cancel();
      }
      _chatMessageSubs.clear();
      _lastNotifiedMessageId.clear();
      _lastNotifiedChatStatus.clear();
      _localListenersUserId = null;
      _buyerChatsLoaded = false;
      _vendorChatsLoaded = false;
    } catch (_) {}
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
        ?.createNotificationChannel(_defaultChannel);

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
    if (kDebugMode) {
      print('Notification tapped with payload: $payload');
    }
    try {
      Map<String, dynamic> data = {};
      if (payload != null && payload.isNotEmpty) {
        // Try JSON first
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            data = Map<String, dynamic>.from(decoded as Map);
          }
        } catch (_) {
          // Fallback: key=value map toString parsing
          if (payload.startsWith('{') && payload.endsWith('}')) {
            final inner = payload.substring(1, payload.length - 1);
            for (final pair in inner.split(',')) {
              final kv = pair.split(':');
              if (kv.length >= 2) {
                data[kv[0].trim()] = kv.sublist(1).join(':').trim();
              }
            }
          }
        }
      }

      final type = (data['type'] ?? data['category'] ?? '').toString().toLowerCase();
      final chatId = data['chatId']?.toString();
      if ((type.contains('chat') || type.contains('order')) && chatId != null && chatId.isNotEmpty) {
        navigateToChatById(chatId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling notification payload: $e');
      }
    }
  }

  // Public: navigate into chat by chatId (buyer or vendor)
  Future<void> navigateToChatById(String chatId) async {
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;
      final data = chatDoc.data() as Map<String, dynamic>;
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final buyerId = data['buyerId']?.toString();
      final vendorId = data['vendorId']?.toString();
      final bundleId = data['bundleId']?.toString() ?? '';
      final recipientNumber = data['recipientNumber']?.toString() ?? '';

      if (userId == buyerId) {
        // Load vendor name for UI
        String businessName = 'Vendor';
        try {
          if (vendorId != null) {
            final vendorDoc = await FirebaseFirestore.instance.collection('users').doc(vendorId).get();
            if (vendorDoc.exists) {
              final vd = vendorDoc.data() as Map<String, dynamic>?;
              businessName = vd?['businessName'] ?? vd?['name'] ?? 'Vendor';
            }
          }
        } catch (_) {}

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              vendorId: vendorId ?? '',
              bundleId: bundleId,
              businessName: businessName,
              recipientNumber: recipientNumber,
            ),
          ),
        );
      } else if (userId == vendorId && buyerId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => VendorChatDetailScreen(
              chatId: chatId,
              buyerId: buyerId,
              buyerName: '',
              bundleId: bundleId,
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to navigate to chat: $e');
      }
    }
  }

  // Handler for notification taps from background
  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification opened from background: ${message.data}');
    }
    // Prefer direct data
    final data = message.data;
    final chatId = data['chatId'] ?? data['chat_id'];
    final type = (data['type'] ?? '').toString().toLowerCase();
    if (chatId != null && type.contains('chat')) {
      navigateToChatById(chatId.toString());
      return;
    }
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
      payload: payload,
    );
  }

  Future<void> showLocalOrderNotification({
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
          _orderChannel.id,
          _orderChannel.name,
          channelDescription: _orderChannel.description,
          icon: '@mipmap/ic_launcher',
          priority: Priority.high,
          importance: Importance.high,
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
      payload: payload,
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