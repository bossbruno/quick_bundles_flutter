import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import 'onesignal_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? name,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create the user document in Firestore
      await _db.createUserDocument(
        credential.user!,
        name: name,
        phoneNumber: phoneNumber,
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
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login timestamp
      await _db.updateUserProfile(credential.user!.uid, {
        'lastLogin': DateTime.now(),
      });
      
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

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
} 