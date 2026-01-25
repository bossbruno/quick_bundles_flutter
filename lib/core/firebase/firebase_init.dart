import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseInit {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          name: 'quick-bundles',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Configure Firestore with offline persistence
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Firestore settings warning: $e');
        }
      }

      // Firebase Auth automatically persists authentication state on mobile (iOS/Android)
      // setPersistence() is only available on web and is deprecated
      // On mobile platforms, auth state persists automatically between app sessions
      if (kDebugMode) {
        print('✅ Firebase Auth persistence is automatic on mobile platforms');
      }

      _initialized = true;
      if (kDebugMode) {
        print('✅ Firebase initialized successfully');
      }
    } catch (e) {
      _initialized = false;
      if (kDebugMode) {
        print('❌ Firebase initialization failed: $e');
      }
    }
  }
}
