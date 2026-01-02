import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'database_service.dart';
import 'onesignal_service.dart';

class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _rememberMeEmailKey = 'remember_me_email';
  static const String _rememberMePasswordKey = 'remember_me_password';

  // Get current user
  User? get currentUser => _auth.currentUser;

  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(key: _rememberMeEmailKey, value: email);
    await _secureStorage.write(key: _rememberMePasswordKey, value: password);
  }

  Future<void> clearRememberedCredentials() async {
    await _secureStorage.delete(key: _rememberMeEmailKey);
    await _secureStorage.delete(key: _rememberMePasswordKey);
  }

  Future<({String email, String password})?> getRememberedCredentials() async {
    final email = await _secureStorage.read(key: _rememberMeEmailKey);
    final password = await _secureStorage.read(key: _rememberMePasswordKey);
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }

  // Send verification email to current user
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    } else if (user == null) {
      throw AuthException('No user is currently signed in.');
    } else {
      throw AuthException('Email is already verified.');
    }
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Send email verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Check if user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? name,
    String? phoneNumber,
  }) async {
    try {
      // Check if email already exists
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        throw AuthException('An account already exists with this email address.');
      }

      // Create user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Send verification email
      await credential.user!.sendEmailVerification();
      
      // Create the user document in Firestore with emailVerified flag
      await _db.createUserDocument(
        credential.user!,
        name: name,
        phoneNumber: phoneNumber,
        emailVerified: false,
      );
      
      // Save OneSignal player ID to Firestore
      await OneSignalService.savePlayerIdToFirestore();
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // First sign in to check credentials
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      if (!credential.user!.emailVerified) {
        // Send verification email if not verified
        await credential.user!.sendEmailVerification();
        throw AuthException(
          'Please verify your email before signing in. A new verification email has been sent to $email',
          code: 'email-not-verified',
        );
      }

      // Check if user profile exists
      final userDoc = await _db.usersCollection.doc(credential.user!.uid).get();
      
      // If profile doesn't exist, create it
      if (!userDoc.exists) {
        await _db.createUserDocument(
          credential.user!,
          name: credential.user!.displayName,
          phoneNumber: credential.user!.phoneNumber,
          emailVerified: credential.user!.emailVerified,
        );
      } else {
        // Update last login time and email verification status
        await _db.usersCollection.doc(credential.user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'emailVerified': credential.user!.emailVerified,
        });
      }

      // Save OneSignal player ID to Firestore
      await OneSignalService.savePlayerIdToFirestore();
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    // Logout from OneSignal
    await OneSignalService.logout();
  }

  // Check and create user profile if it doesn't exist
  Future<void> checkAndCreateUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _db.usersCollection.doc(user.uid).get();
      if (!userDoc.exists) {
        await _db.createUserDocument(
          user,
          name: user.displayName,
          phoneNumber: user.phoneNumber,
          emailVerified: user.emailVerified,
        );
      } else {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['emailVerified'] != user.emailVerified) {
          // Update email verification status if it has changed
          await _db.usersCollection.doc(user.uid).update({
            'emailVerified': user.emailVerified,
          });
        }
      }
    }
  }

  // Update vendor profile
  Future<void> updateVendorProfile({
    required String userId,
    String? about,
    String? phone,
    String? email,
    String? businessHours,
    List<String>? serviceAreas,
    Map<String, bool>? paymentMethods,
  }) async {
    try {
      final userData = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      // Add fields to update if they are provided
      if (about != null) userData['about'] = about;
      if (phone != null) userData['phone'] = phone;
      if (email != null) userData['email'] = email;
      if (businessHours != null) userData['businessHours'] = businessHours;
      if (serviceAreas != null) userData['serviceAreas'] = serviceAreas;
      if (paymentMethods != null) userData['paymentMethods'] = paymentMethods;

      // Update user document in Firestore
      await _db.usersCollection.doc(userId).update(userData);

      // Update email in Firebase Auth if it was changed
      if (email != null && _auth.currentUser?.email != email) {
        await _auth.currentUser?.updateEmail(email);
      }
    } catch (e) {
      throw Exception('Failed to update vendor profile: $e');
    }
  }

  // Password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    } else if (user == null) {
      throw AuthException('No user is currently signed in.');
    } else {
      throw AuthException('Email is already verified.');
    }
  }

  // Check if user needs to verify their email
  Future<bool> needsEmailVerification() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified == false;
  }

  // Handle auth exceptions
  AuthException _handleAuthException(FirebaseAuthException e) {
    String message;
    
    switch (e.code) {
      case 'invalid-email':
        message = 'The email address is badly formatted.';
        break;
      case 'user-disabled':
        message = 'This user account has been disabled.';
        break;
      case 'user-not-found':
        message = 'No account found with this email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password. Please try again.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email address.';
        break;
      case 'operation-not-allowed':
        message = 'Email/password accounts are not enabled.';
        break;
      case 'weak-password':
        message = 'The password is too weak. Please choose a stronger password.';
        break;
      case 'too-many-requests':
        message = 'Too many requests. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your internet connection.';
        break;
      case 'requires-recent-login':
        message = 'Please log in again to verify your identity.';
        break;
      default:
        message = e.message ?? 'An error occurred. Please try again.';
    }
    
    return AuthException(message);
  }
}