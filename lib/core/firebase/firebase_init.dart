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

      // Configure Firebase Auth persistence
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        if (kDebugMode) {
          print('✅ Firebase Auth persistence enabled');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Firebase Auth persistence warning: $e');
        }
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
