import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/onesignal_config.dart';

class OneSignalService {
  // Use credentials from config file
  static const String oneSignalAppId = OneSignalConfig.appId;
  static const String restApiKey = OneSignalConfig.restApiKey;

  /// Initialize OneSignal
  static Future<void> initialize() async {
    try {
      // Set app ID and initialize
      OneSignal.initialize(oneSignalAppId);
      
      // Enable verbose logging in debug mode
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // Request permission to send notifications
      OneSignal.Notifications.requestPermission(true).then((permission) {
        print('Notification permission granted: $permission');
      });

      // Set up notification click handler
      OneSignal.Notifications.addClickListener((event) {
        print('Notification clicked: ${event.notification.jsonRepresentation()}');
        // Handle notification click here (e.g., navigate to chat)
        final data = event.notification.additionalData;
        if (data != null && data['chatId'] != null) {
          // You can add navigation logic here if needed
          print('Chat ID from notification: ${data['chatId']}');
        }
      });

      // Set up foreground notification handler
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print('Notification received in foreground: ${event.notification.jsonRepresentation()}');
        // You can customize the notification or prevent it from showing
        // event.notification.setTitle('New message!');
        // event.notification.setBody('You have a new message');
      });

      // Set up push subscription observer
      OneSignal.User.pushSubscription.addObserver((state) async {
        if (state.current.id != null) {
          print('Push subscription changed. New ID: ${state.current.id}');
          // Save the new player ID to Firestore
          await savePlayerIdToFirestore();
        }
      });

      // Initialize with current user if available
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await OneSignal.login(user.uid);
        if (user.email != null) {
          await OneSignal.User.addEmail(user.email!);
        }
        // Save the player ID to Firestore
        await savePlayerIdToFirestore();
      }
    } catch (e) {
      print('Error initializing OneSignal: $e');
      rethrow;
    }
  }

  /// Save player ID to Firestore after user login/signup
  static Future<void> savePlayerIdToFirestore() async {
    try {
      // Get the current OneSignal player ID
      String? playerId = await OneSignal.User.pushSubscription.id;
      final user = FirebaseAuth.instance.currentUser;
      
      if (playerId == null || playerId.isEmpty) {
        print('Warning: OneSignal player ID is null or empty');
        return;
      }
      
      if (user == null) {
        print('Warning: No authenticated user found');
        return;
      }
      
      // Update the user document with the OneSignal player ID
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'oneSignalPlayerId': playerId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      print('OneSignal Player ID saved to Firestore for user ${user.uid}: $playerId');
      
      // Also set the external user ID in OneSignal for targeting
      await OneSignal.login(user.uid);
      
      // Update the user's email in OneSignal if available
      if (user.email != null) {
        await OneSignal.User.addEmail(user.email!);
      }
      
    } catch (e) {
      print('Error saving OneSignal Player ID: $e');
      // Re-throw the error to be handled by the caller
      rethrow;
    }
  }

  /// Send a notification to a specific user
  static Future<void> sendNotification({
    required String playerId,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
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
        print('OneSignal notification sent successfully!');
      } else {
        print('Failed to send OneSignal notification: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending OneSignal notification: $e');
    }
  }

  /// Send a chat notification to a recipient's player ID
  static Future<void> sendChatNotification({
    required String playerId,
    required String message,
    required String senderName,
    String? chatId,
  }) async {
    try {
      if (playerId.isEmpty) {
        print('Error: Player ID is empty');
        return;
      }
      
      print('Sending chat notification to player ID: $playerId');
      
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
      
      print('Chat notification sent successfully to player ID: $playerId');
    } catch (e) {
      print('Error in sendChatNotification: $e');
      rethrow;
    }
  }

  /// Send notification to multiple users
  static Future<void> sendNotificationToMultiple({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
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
        print('OneSignal notification sent to ${playerIds.length} users successfully!');
    } else {
        print('Failed to send OneSignal notification: ${response.statusCode} - ${response.body}');
    }
    } catch (e) {
      print('Error sending OneSignal notification: $e');
    }
  }

  /// Get current user's OneSignal ID
  static Future<String?> getCurrentPlayerId() async {
    return await OneSignal.User.pushSubscription.id;
  }

  /// Logout from OneSignal
  static Future<void> logout() async {
    await OneSignal.logout();
  }
} 