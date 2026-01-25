import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_bundles_flutter/core/firebase/firebase_init.dart';
import 'package:quick_bundles_flutter/features/auth/screens/login_screen.dart';
import 'package:quick_bundles_flutter/features/marketplace/screens/marketplace_screen.dart';
import 'package:quick_bundles_flutter/features/vendor/screens/vendor_dashboard_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _auth = FirebaseAuth.instance;
  bool _initialized = false;
  bool _error = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Ensure Firebase is initialized first
      if (!FirebaseInit.isInitialized) {
        await FirebaseInit.initialize();
      }
      
      // Wait for auth state to be ready - Firebase Auth persists state automatically on mobile
      // Listen to auth state changes stream to wait for initial state
      await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Timeout is okay - we'll proceed with current user check
          return _auth.currentUser;
        },
      );
      
      // Check if user is already signed in
      final currentUser = _auth.currentUser;
      if (kDebugMode) {
        print('Current user on init: ${currentUser?.uid ?? 'null'}');
        if (currentUser != null) {
          print('User email: ${currentUser.email}');
          print('User metadata - Created: ${currentUser.metadata.creationTime}');
          print('User metadata - Last sign in: ${currentUser.metadata.lastSignInTime}');
        }
      }
      
      setState(() => _initialized = true);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing auth: $e');
      }
      setState(() {
        _error = true;
        _errorMessage = 'Failed to initialize. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'An error occurred',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = false;
                      _initialized = false;
                      _initializeAuth();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state initially
        if (snapshot.connectionState == ConnectionState.waiting && !_initialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle errors in auth state
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('Auth state error: ${snapshot.error}');
          }
          return const LoginScreen();
        }

        // Check current user - Firebase Auth automatically persists auth state on mobile
        // If snapshot has no data, also check currentUser directly as fallback
        final user = snapshot.data ?? _auth.currentUser;

        // If user is not authenticated, show login screen
        if (user == null) {
          if (kDebugMode) {
            print('No authenticated user found');
          }
          return const LoginScreen();
        }

        // User is authenticated, check their profile
        if (kDebugMode) {
          print('User authenticated: ${user.uid}, Email: ${user.email}');
        }
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            // Show loading indicator while fetching user data
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Handle errors or missing user data
            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User profile not found. Please log in again.'),
                    duration: Duration(seconds: 3),
                  ),
                );
                _auth.signOut();
              });
              return const LoginScreen();
            }

            // Get user type and navigate to appropriate screen
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final userType = userData?['userType']?.toString().toLowerCase() ?? 'user';
            
            if (userType == 'vendor') {
              return const VendorDashboardScreen();
            } else {
              return const MarketplaceScreen();
            }
          },
        );
      },
    );
  }
}