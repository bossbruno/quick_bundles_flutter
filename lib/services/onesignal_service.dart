import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config/onesignal_config.dart';

class OneSignalService {
  // Static-only utility. Instantiate is unnecessary.
  static void _logD(String message) {
    if (kDebugMode) debugPrint('[OneSignal] $message');
  }

  static void _logE(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[OneSignal][ERROR] $message');
      if (error != null) debugPrint('  error: $error');
      if (stackTrace != null) debugPrint('  stack: $stackTrace');
    }
  }

  static const String oneSignalAppId = OneSignalConfig.appId;
  static const String restApiKey = OneSignalConfig.restApiKey;
  static bool _isInitialized = false;
  static bool _isUserLoggedIn = false;
  static String? _currentUserId;

  static bool get _canSendFromClient => restApiKey.trim().isNotEmpty;

  static Future<void> initialize() async {
    try {
      if (_isInitialized) {
        _logD('OneSignal already initialized');
        return;
      }

      _isInitialized = true;

      // Set app ID and initialize
      OneSignal.initialize(oneSignalAppId);

      // Enable verbose logging in debug mode
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // Request permission to send notifications
      OneSignal.Notifications.requestPermission(true).then((permission) {
        _logD('Notification permission granted: $permission');
      });

      _setupNotificationHandlers();
      _setupSubscriptionObserver();

      // Initialize with current user if available
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _initializeCurrentUser();
      }
    } catch (e) {
      _logE('Error initializing OneSignal', error: e);
      rethrow;
    }
  }

  static void _setupNotificationHandlers() {
    // Handle notification clicks
    OneSignal.Notifications.addClickListener((event) {
      try {
        final notification = event.notification;
        final data = notification.additionalData;

        _logD('Notification clicked: ${notification.notificationId}');
        _logD('Notification data: $data');

        if (data != null) {
          _handleNotificationClick(data);
        }
      } catch (e, stackTrace) {
        _logE('Error handling notification click', error: e, stackTrace: stackTrace);
      }
    });

    // Handle foreground notifications
    OneSignal.Notifications.addForegroundWillDisplayListener(_onForegroundNotification);
  }

  static void _setupSubscriptionObserver() {
    OneSignal.User.pushSubscription.addObserver(_onPushSubscriptionChange);
  }

  static void _onForegroundNotification(dynamic event) {
    try {
      final notification = event.notification;
      _logD('Foreground notification received: ${notification.notificationId}');

      // Log notification details
      _logD('Title: ${notification.title}');
      _logD('Body: ${notification.body}');
      _logD('Data: ${notification.additionalData}');

      // You can customize the notification here if needed

      // Call complete to display the notification
      // If you don't call complete, the notification won't be shown
      event.complete(notification);
    } catch (e, stackTrace) {
      _logE('Error handling foreground notification', error: e, stackTrace: stackTrace);
    }
  }

  static void _onPushSubscriptionChange(dynamic changes) async {
    try {
      final newId = changes.current?.id;
      if (newId != null) {
        _logD('Push subscription changed. New ID: $newId');

        // Save the new player ID to Firestore
        await savePlayerIdToFirestore();

        // If we have a user logged in, update their subscription
        if (_isUserLoggedIn && _currentUserId != null) {
          await _updateUserSubscription(newId);
        }
      }
    } catch (e, stackTrace) {
      _logE('Error handling push subscription change', error: e, stackTrace: stackTrace);
    }
  }

  static Future<void> _initializeCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
        _isUserLoggedIn = true;

        // Set external user ID for OneSignal
        await OneSignal.login(user.uid);

        // Add user email if available
        if (user.email != null) {
          await OneSignal.User.addEmail(user.email!);
        }

        // Save player ID to Firestore
        await savePlayerIdToFirestore();

        _logD('Initialized OneSignal for user: ${user.uid}');
      } else {
        _logD('No user logged in, OneSignal will be initialized anonymously');
        _isUserLoggedIn = false;
        _currentUserId = null;
      }
    } catch (e, stackTrace) {
      _logE('Error initializing OneSignal user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<void> savePlayerIdToFirestore() async {
    try {
      final playerId = await OneSignal.User.pushSubscription.id;
      final user = FirebaseAuth.instance.currentUser;

      if (playerId == null || playerId.isEmpty) {
        _logD('OneSignal player ID is null or empty');
        return;
      }

      if (user == null) {
        _logD('No authenticated user found, cannot save player ID');
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final updateData = <String, dynamic>{
        'oneSignalPlayerId': playerId,
        'oneSignalLastUpdated': FieldValue.serverTimestamp(),
        'deviceInfo': await _getDeviceInfo(),
      };

      // Use set with merge to avoid overwriting other fields
      await userRef.set(updateData, SetOptions(merge: true));

      _logD('Saved OneSignal player ID for user ${user.uid}');
    } catch (e, stackTrace) {
      _logE('Failed to save OneSignal player ID', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      // Device API details vary by SDK; keep minimal info here
      final playerId = await OneSignal.User.pushSubscription.id;
      return {
        'playerId': playerId,
        'timestamp': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      _logE('Failed to get device info', error: e);
      return {'error': e.toString()};
    }
  }

  static Future<bool> sendPushNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
    String? category,
    int priority = OneSignalConfig.highPriority,
  }) async {
    try {
      if (!_canSendFromClient) {
        _logE('OneSignal REST API key is not configured. Skipping client-side sendPushNotification. Use a backend (e.g. Firebase Functions) to send pushes.');
        return false;
      }
      _logD('Sending push notification to user: $userId');
      _logD('Title: $title');
      _logD('Message: $message');
      _logD('Data: $data');

      // In a production app, you should call your backend server
      // which would then send the notification using the OneSignal API
      // This is a simplified example that calls the API directly from the client

      // Prepare the notification data
      final notificationData = Map<String, dynamic>.from(data);
      notificationData['type'] = category ?? data['type'] ?? 'general';

      // Determine the sound based on category
      String sound = OneSignalConfig.defaultSound;
      if (category == 'chat') {
        sound = OneSignalConfig.messageSound;
      } else if (category == 'order') {
        sound = OneSignalConfig.orderSound;
      }

      // Prepare the request body
      final body = {
        'app_id': oneSignalAppId,
        'include_external_user_ids': [userId],
        'contents': {'en': message},
        'headings': {'en': title},
        'data': notificationData,
        'android_channel_id': category == 'chat'
            ? OneSignalConfig.chatChannelId
            : OneSignalConfig.orderChannelId,
        'ios_sound': '$sound.wav',
        'android_sound': sound,
        'priority': priority,
        'ttl': OneSignalConfig.notificationTimeout,
        'android_visibility': OneSignalConfig.publicVisibility ? 1 : 0,
        'small_icon': 'ic_notification',
        'large_icon': 'ic_launcher',
        'android_accent_color': 'FF00B8D4',
        'ios_category': category ?? 'general',
      };

      _logD('Sending notification with data: $body');

      // Send the request to OneSignal API
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode(body),
      );

      _logD('Notification sent. Status code: ${response.statusCode}');
      _logD('Response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to send notification: ${response.body}');
      }

      return true;
    } catch (e, stackTrace) {
      _logE('Failed to send push notification', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendBulkPushNotification({
    required List<String> userIds,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
    String? category,
    int priority = OneSignalConfig.defaultPriority,
  }) async {
    try {
      if (!_canSendFromClient) {
        _logE('OneSignal REST API key is not configured. Skipping client-side sendBulkPushNotification. Use a backend (e.g. Firebase Functions) to send pushes.');
        return {'success': false, 'message': 'OneSignal REST API key is not configured'};
      }
      if (userIds.isEmpty) {
        _logD('No user IDs provided for bulk notification');
        return {'success': false, 'message': 'No user IDs provided'};
      }

      _logD('Sending bulk notification to ${userIds.length} users');

      // In a production app, you should call your backend server
      // which would handle batching and rate limiting

      int success = 0;
      int failed = 0;
      final Map<String, dynamic> errors = {};

      // Process notifications in batches to avoid rate limiting
      const batchSize = 100;
      for (var i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();
        _logD('Processing batch ${i ~/ batchSize + 1} of ${(userIds.length / batchSize).ceil()}');

        for (final userId in batch) {
          try {
            await sendPushNotification(
              userId: userId,
              title: title,
              message: message,
              data: data,
              category: category,
              priority: priority,
            );
            success = success + 1;
          } catch (e) {
            failed = failed + 1;
            errors[userId] = e.toString();
            _logE('Failed to send to user $userId: $e');
          }
        }

        // Add a small delay between batches
        if (i + batchSize < userIds.length) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      _logD('Bulk notification completed: $success successful, $failed failed');
      return {
        'success': true,
        'total': userIds.length,
        'successCount': success,
        'failedCount': failed,
        'errors': errors,
      };
    } catch (e, stackTrace) {
      _logE('Failed to send bulk push notification', error: e, stackTrace: stackTrace);
      return {
        'success': false,
        'message': e.toString(),
        'total': userIds.length,
        'successCount': 0,
        'failedCount': userIds.length,
        'errors': {'all': e.toString()},
      };
    }
  }

  static Future<void> _updateUserSubscription(String playerId) async {
    try {
      if (_currentUserId == null) {
        _logD('No current user, skipping subscription update');
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);

      await userRef.update({
        'notificationSettings': {
          'oneSignalPlayerId': playerId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'isSubscribed': true,
        },
      });

      _logD('Updated user subscription for $_currentUserId');
    } catch (e, stackTrace) {
      _logE('Failed to update user subscription', error: e, stackTrace: stackTrace);
    }
  }

  static Future<void> logEvent({
    required String eventName,
    Map<String, dynamic>? eventData,
  }) async {
    // No-op simplified analytics logging to avoid SDK differences
    _logD('Event: $eventName data: ${eventData ?? {}}');
  }

  static Future<void> addTag(String key, String value) async {
    try {
      if (!_isInitialized) {
        _logD('OneSignal not initialized, cannot add tag');
        return;
      }

      await OneSignal.User.addTags({key: value});
      _logD('Added tag: $key = $value');
    } catch (e, stackTrace) {
      _logE('Failed to add tag', error: e, stackTrace: stackTrace);
    }
  }

  static Future<void> removeTag(String key) async {
    try {
      if (!_isInitialized) {
        _logD('OneSignal not initialized, cannot remove tag');
        return;
      }

      await OneSignal.User.removeTags([key]);
      _logD('Removed tag: $key');
    } catch (e, stackTrace) {
      _logE('Failed to remove tag', error: e, stackTrace: stackTrace);
    }
  }

  static void _handleNotificationClick(Map<dynamic, dynamic> data) {
    try {
      final type = data['type']?.toString().toLowerCase();
      _logD('Handling notification click of type: $type');

      if (type == null) {
        _logD('Notification has no type');
        return;
      }

      switch (type) {
        case 'chat':
          _handleChatNotification(data);
          break;

        case 'order':
          _handleOrderNotification(data);
          break;

        case 'promotion':
          _handlePromotionNotification(data);
          break;

        default:
          _logD('Unknown notification type: $type');
          _handleDefaultNotification(data);
      }
    } catch (e, stackTrace) {
      _logE('Error handling notification click', error: e, stackTrace: stackTrace);
    }
  }

  static void _handleChatNotification(Map<dynamic, dynamic> data) {
    final chatId = data['chatId']?.toString();
    final bundleId = data['bundleId']?.toString();
    final vendorId = data['vendorId']?.toString();

    if (chatId == null) {
      _logD('Chat notification is missing chatId');
      return;
    }

    _logD('Opening chat: $chatId');

    // Navigate to chat screen
    // Example using GetX:
    /*
    Get.to(
      () => ChatScreen(
        chatId: chatId,
        bundleId: bundleId ?? '',
        vendorId: vendorId ?? '',
      ),
      preventDuplicates: false,
    );
    */
  }

  static void _handleOrderNotification(Map<dynamic, dynamic> data) {
    final orderId = data['orderId']?.toString();

    if (orderId == null) {
      _logD('Order notification is missing orderId');
      return;
    }

    _logD('Opening order: $orderId');

    // Navigate to order details screen
    /*
    Get.to(
      () => OrderDetailsScreen(orderId: orderId),
      preventDuplicates: false,
    );
    */
  }

  static void _handlePromotionNotification(Map<dynamic, dynamic> data) {
    final promoId = data['promoId']?.toString();
    final deepLink = data['deepLink']?.toString();

    if (deepLink != null) {
      _logD('Opening deep link: $deepLink');
      // Handle deep link
      // _handleDeepLink(deepLink);
    } else if (promoId != null) {
      _logD('Opening promotion: $promoId');
      // Navigate to promotion details
      /*
      Get.to(
        () => PromotionDetailsScreen(promoId: promoId),
        preventDuplicates: false,
      );
      */
    } else {
      _logD('Promotion notification has no deep link or promoId');
    }
  }

  static void _handleDefaultNotification(Map<dynamic, dynamic> data) {
    _logD('Handling default notification');
    // You can add default handling here
  }

  static Future<void> sendChatNotification({
    required String playerId,
    required String message,
    required String senderName,
    String? chatId,
  }) async {
    try {
      if (!_canSendFromClient) {
        _logE('OneSignal REST API key is not configured. Skipping client-side sendChatNotification. Use a backend (e.g. Firebase Functions) to send pushes.');
        return;
      }
      if (playerId.isEmpty) {
        _logD('Player ID is empty');
        return;
      }

      _logD('Sending chat notification to player ID: $playerId');

      await sendNotification(
        playerId: playerId,
        title: 'New message from $senderName',
        message: message,
        additionalData: {
          'type': 'chat_message',
          'chatId': chatId,
          'senderName': senderName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logD('Chat notification sent successfully to player ID: $playerId');
    } catch (e) {
      _logE('Error in sendChatNotification', error: e);
      rethrow;
    }
  }

  /// Send notification to a single device by playerId
  static Future<void> sendNotification({
    required String playerId,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (!_canSendFromClient) {
        _logE('OneSignal REST API key is not configured. Skipping client-side sendNotification. Use a backend (e.g. Firebase Functions) to send pushes.');
        return;
      }
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': oneSignalAppId,
          'include_player_ids': [playerId],
          'headings': {'en': title},
          'contents': {'en': message},
          'data': additionalData ?? {},
        }),
      );

      if (response.statusCode == 200) {
        _logD('OneSignal notification sent to playerId: $playerId');
      } else {
        _logE('Failed to send OneSignal notification: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _logE('Error sending OneSignal notification', error: e);
    }
  }

  /// Send notification to multiple devices by playerIds
  static Future<void> sendNotificationToMultiple({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (!_canSendFromClient) {
        _logE('OneSignal REST API key is not configured. Skipping client-side sendNotificationToMultiple. Use a backend (e.g. Firebase Functions) to send pushes.');
        return;
      }
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': oneSignalAppId,
          'include_player_ids': playerIds,
          'headings': {'en': title},
          'contents': {'en': message},
          'data': additionalData ?? {},
        }),
      );

      if (response.statusCode == 200) {
        _logD('OneSignal notification sent to ${playerIds.length} users successfully');
      } else {
        _logE('Failed to send OneSignal notification: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _logE('Error sending OneSignal notification', error: e);
    }
  }

  /// Get current user's OneSignal Player ID
  static Future<String?> getCurrentPlayerId() async {
    return await OneSignal.User.pushSubscription.id;
  }

  /// Logout from OneSignal (static)
  static Future<void> logoutUser() async {
    await OneSignal.logout();
  }

  /// Backwards-compat: some code calls OneSignalService.logout() statically
  static Future<void> logout() => logoutUser();
}
 