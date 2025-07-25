import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import '../../services/notification_service.dart';

class FirebaseInit {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize notification service
      await NotificationService().initialize();

      if (kDebugMode) {
        print('Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize Firebase: $e');
      }
    }
  }
}