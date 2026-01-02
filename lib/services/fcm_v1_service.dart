import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/fcm/v1.dart' as fcm;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/auth_io.dart';

class FCMV1Service {
  static final FCMV1Service _instance = FCMV1Service._internal();

  factory FCMV1Service() => _instance;

  late final FirebaseMessaging _fcm;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();
  static const String _serviceAccountKey = 'fcm_service_account';

  String? _projectId;
  String? _clientEmail;
  String? _privateKey;
  bool _initialized = false;

  FCMV1Service._internal() {
    _fcm = FirebaseMessaging.instance;
  }

  // Initialize FCM service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load service account if needed
      try {
        final jsonString = await rootBundle.loadString(
            'assets/config/service-account.json');
      await _storage.write(key: _serviceAccountKey, value: jsonString);
      
      // Parse project ID
      final json = jsonDecode(jsonString);
      _projectId = json['project_id'];
        _clientEmail = json['client_email'];
        _privateKey = json['private_key'];
      } catch (e) {
        debugPrint('Warning: Could not load service account: $e');
      }

      // Request permissions and setup handlers
      await _setupFCM();

      _initialized = true;
      debugPrint('FCM V1 Service initialized');
    } catch (e) {
      debugPrint('FCM init error: $e');
      rethrow;
    }
  }

  Future<void> _setupFCM() async {
    try {
      // Request notification permissions
      await _requestPermissions();

      // Note: Do not attach global message handlers here.
      // NotificationService is the single source of truth for onMessage/onBackgroundMessage.

      // Get initial token
      final token = await _fcm.getToken();
      if (token != null) {
        final len = token.length;
        final end = len < 12 ? len : 12;
        debugPrint('Initial FCM Token: ${token.substring(0, end)}...');
      }

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        final len = newToken.length;
        final end = len < 12 ? len : 12;
        debugPrint('FCM Token refreshed: ${newToken.substring(0, end)}...');
        // TODO: Update the token on your server
      });

      // Foreground presentation is handled in NotificationService.initialize().
    } catch (e) {
      debugPrint('Error setting up FCM: $e');
      rethrow;
    }
  }

  // Get authenticated client
  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    final jsonString = await _storage.read(key: _serviceAccountKey);
    if (jsonString == null) {
      throw Exception('Service account not found');
    }
    final credentials = ServiceAccountCredentials.fromJson(
        jsonDecode(jsonString));
    // Use the proper FCM scope
    return clientViaServiceAccount(
        credentials, ['https://www.googleapis.com/auth/firebase.messaging']);
  }

  // Send push notification with improved error handling
  Future<void> sendMessage({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? sound = 'default',
    String? clickAction,
    String? category,
  }) async {
    if (_projectId == null) await initialize();

    // Token validation
    if (token.isEmpty) {
      debugPrint('FCM Error: Empty token provided');
      throw Exception('Empty FCM token');
    }

    debugPrint('Sending FCM to token: ${token.substring(
        0, min(token.length, 12))}...');

    final client = await _getAuthClient();
    final fcmApi = fcm.FirebaseCloudMessagingApi(client);
    
    try {
      // Create notification payload
      final notification = fcm.Notification()
        ..title = title
        ..body = body;
      
      // Android configuration
      final androidConfig = fcm.AndroidConfig()
        ..priority = 'high'
        ..notification = fcm.AndroidNotification(
          channelId: 'chat_notifications',
          sound: sound,
          clickAction: clickAction ?? 'FLUTTER_NOTIFICATION_CLICK',
          tag: 'chat_${DateTime
              .now()
              .millisecondsSinceEpoch}',
        );
      
      // APNS configuration for iOS
      final apnsConfig = fcm.ApnsConfig(
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
          'apns-topic': 'com.theden.quickbundles',
        },
        payload: {
          'aps': {
            'alert': {
              'title': title,
              'body': body,
            },
            'sound': sound,
            'badge': 1,
            'category': category ?? 'MESSAGE_CATEGORY',
            'mutable-content': 1,
            'content-available': 1,
          },
          ...?data,
        },
      );
      
      // Build the message
      final message = fcm.Message()
        ..token = token
        ..notification = notification
        ..data = {
          ...?data,
          'click_action': clickAction ?? 'FLUTTER_NOTIFICATION_CLICK',
          'sound': sound ?? 'default',
        }
        ..android = androidConfig
        ..apns = apnsConfig
        ..fcmOptions = fcm.FcmOptions(
          analyticsLabel: 'chat_message',
        );
      
      // Send with retry logic
      int retries = 2;
      while (retries >= 0) {
        try {
      await fcmApi.projects.messages.send(
            fcm.SendMessageRequest()
              ..message = message,
        'projects/$_projectId',
      );
          debugPrint('FCM sent successfully');
          return;
        } on fcm.DetailedApiRequestError catch (e) {
          debugPrint('FCM API Error (${e.status}): ${e.message}');

          if (e.status == 404 || e.status == 401) {
            // Invalid token or authentication error
            if (retries > 0) {
              debugPrint('Refreshing FCM token and retrying...');
              await _refreshFcmToken();
              retries--;
              continue;
            }
          }
          rethrow;
        } catch (e) {
          debugPrint('Error sending FCM: $e');
          if (retries == 0) rethrow;
          retries--;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } finally {
      client.close();
    }
  }

  // Get FCM token with retry logic
  Future<String?> getFCMToken() async {
    int retries = 3;
    while (retries > 0) {
      try {
        final token = await _fcm.getToken();

        if (token != null && token.isNotEmpty) {
          final len = token.length;
          final end = len < 12 ? len : 12;
          debugPrint('FCM Token: ${token.substring(0, end)}...');
          return token;
        }
      } catch (e) {
        debugPrint('Error getting FCM token (${4 - retries}/3): $e');
        if (retries == 1) rethrow;
      }

      await Future.delayed(const Duration(seconds: 1));
      retries--;
    }
    return null;
  }

  // Request permissions with enhanced error handling and token management
  Future<void> _requestPermissions() async {
    try {
      // Request notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint(
          'Notification permission status: ${settings.authorizationStatus}');

      // Get token after requesting permissions with retry logic
      String? token;
      int retries = 3;

      while (retries > 0 && token == null) {
        try {
          token = await _fcm.getToken();
          if (token == null) {
            retries--;
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          debugPrint('Error getting token (${4 - retries}/3): $e');
          retries--;
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (token != null) {
        final len = token.length;
        final end = len < 12 ? len : 12;
        debugPrint('FCM Token: ${token.substring(0, end)}...');
      } else {
        debugPrint('FCM Token: null');
      }

      // Token refresh handling is owned by NotificationService to avoid duplicates.

      // Set APNS token if on iOS
      if (Platform.isIOS) {
        final apnsToken = await _fcm.getAPNSToken();
        debugPrint('APNS Token: $apnsToken');
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      rethrow;
    }
  }

  // Handle incoming messages
  void _handleMessage(RemoteMessage message) {
    debugPrint('Message received: ${message.messageId}');
    debugPrint('Data: ${message.data}');
    debugPrint('Notification: ${message.notification?.title}');
  }

  // Refresh FCM token
  Future<void> _refreshFcmToken() async {
    try {
      await _fcm.deleteToken();
      // Get new token
      final newToken = await _fcm.getToken();
      if (newToken != null) {
        debugPrint('Successfully refreshed FCM token');
        // TODO: Update the token on your server
      } else {
        debugPrint('Failed to get new FCM token after refresh');
      }
    } catch (e) {
      debugPrint('Error refreshing FCM token: $e');
      rethrow;
    }
  }
}

// Background handler
@pragma('vm:entry-point')
Future<void> fcmV1MessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}
