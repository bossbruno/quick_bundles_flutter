import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseInit {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;
  static FirebaseApp? _firebaseApp;

  static Future<FirebaseApp> initialize() async {
    if (_initialized && _firebaseApp != null) return _firebaseApp!;
    
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Initialize Firebase only if it hasn't been initialized yet
      if (Firebase.apps.isEmpty) {
        _firebaseApp = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        _firebaseApp = Firebase.app();
      }

      // Configure Firestore with offline persistence
      try {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
        
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          sslEnabled: true,
        );
        
        if (kDebugMode) {
          print('✅ Firestore persistence configured');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Firestore settings warning: $e');
        }
      }

      // Force a check of the current user to warm up the auth state
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (kDebugMode) {
          print('🔍 Initial auth check - User: ${user?.uid ?? 'null'}');
          if (user != null) {
            print('   Email: ${user.email}');
            print('   Email verified: ${user.emailVerified}');
            print('   Last sign-in: ${user.metadata.lastSignInTime}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Initial auth check failed: $e');
        }
      }

      _initialized = true;
      if (kDebugMode) {
        print('✅ Firebase initialized successfully');
      }
      
      return _firebaseApp!;
    } catch (e) {
      _initialized = false;
      if (kDebugMode) {
        print('❌ Firebase initialization failed: $e');
      }
      // If we get here, we need to ensure we still return a FirebaseApp instance
      // by falling back to the default app or initializing a new one
      try {
        _firebaseApp = Firebase.app();
        return _firebaseApp!;
      } catch (_) {
        // If we can't get the default app, try initializing with default options
        _firebaseApp = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        return _firebaseApp!;
      }
    }
  }
}
