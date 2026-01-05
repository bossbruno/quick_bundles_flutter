import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_bundles_flutter/core/firebase/firebase_init.dart';
import 'package:quick_bundles_flutter/features/auth/screens/login_screen.dart';
import 'package:quick_bundles_flutter/features/marketplace/screens/marketplace_screen.dart';
import 'package:quick_bundles_flutter/features/vendor/screens/vendor_dashboard_screen.dart';
import 'package:quick_bundles_flutter/services/auth_service.dart';

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
  bool _autoLoginAttempted = false;
  ({String email, String password})? _remembered;

  Future<bool> _tryAutoLoginIfPossible() async {
    if (_autoLoginAttempted) {
      if (kDebugMode) print('🚫 AuthWrapper: Auto-login already attempted, skipping');
      return false;
    }
    _autoLoginAttempted = true;

    final authService = AuthService();
    final creds = await authService.getRememberedCredentials();
    _remembered = creds;
    if (creds == null) {
      if (kDebugMode) print('❌ AuthWrapper: No remembered credentials found');
      return false;
    }

    if (kDebugMode) print('🔐 AuthWrapper: Attempting auto-login for: ${creds.email}');
    try {
      await authService.signInWithEmailAndPassword(
        email: creds.email,
        password: creds.password,
      );
      final success = authService.currentUser != null;
      if (kDebugMode) print('🎉 AuthWrapper: Auto-login ${success ? 'succeeded' : 'failed'}');
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AuthWrapper: Auto-login failed: $e');
      }
      return false;
    }
  }

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
      
      // Give Firebase Auth time to restore persisted session from local storage
      // This is critical when app reopens - auth state needs time to be restored
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check current user immediately (Firebase Auth persists on mobile automatically)
      var currentUser = _auth.currentUser;
      
      if (kDebugMode) {
        print('🔐 AuthWrapper: Initial check - User: ${currentUser?.uid ?? 'null'}');
      }
      
      // Wait for auth state changes stream to emit initial state
      // This ensures we catch the persisted auth state when app reopens
      try {
        final streamUser = await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // If timeout, return currentUser as fallback
            // This handles cases where stream doesn't emit but user exists
            if (kDebugMode) {
              print('⚠️ AuthWrapper: Stream timeout, using currentUser fallback');
            }
            return _auth.currentUser;
          },
        );
        
        // Prefer stream data over direct currentUser check
        currentUser = streamUser ?? currentUser;
        
        if (kDebugMode) {
          print('🔐 AuthWrapper: After stream - User: ${currentUser?.uid ?? 'null'}');
        }
      } catch (e) {
        // Fallback to currentUser if stream fails
        if (kDebugMode) {
          print('⚠️ AuthWrapper: Stream error: $e, using currentUser fallback');
        }
        currentUser = _auth.currentUser ?? currentUser;
      }
      
      // Final check - get the most up-to-date user from Firebase Auth
      currentUser = _auth.currentUser ?? currentUser;
      
      // If we have a user, verify the token is still valid
      if (currentUser != null) {
        try {
          // Reload to refresh the token and verify it's still valid
          // This helps restore the session if it was persisted
          await currentUser.reload();
          
          // Get refreshed user after reload
          currentUser = _auth.currentUser ?? currentUser;
          
          if (kDebugMode) {
            print('✅ AuthWrapper: User session restored successfully');
            print('   User ID: ${currentUser.uid}');
            print('   Email: ${currentUser.email}');
            print('   Email Verified: ${currentUser.emailVerified}');
            print('   Last Sign In: ${currentUser.metadata.lastSignInTime}');
            print('   Creation Time: ${currentUser.metadata.creationTime}');
          }
        } catch (e) {
          // If reload fails, the token might be expired or invalid
          // Check if it's a token expiry error or network error
          if (kDebugMode) {
            print('⚠️ AuthWrapper: Could not reload user token: $e');
            // If token is expired, currentUser will be null after error
            // But we'll let the StreamBuilder handle this - it will show login if needed
            currentUser = _auth.currentUser ?? currentUser;
            if (currentUser == null) {
              print('   Token expired or invalid - user needs to sign in again');
            } else {
              print('   Using existing user despite reload error');
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ AuthWrapper: No persisted session found');
        }

        // Try auto-login using securely stored credentials (Remember me)
        await _tryAutoLoginIfPossible();
        
        // Refresh remembered credentials in case they changed during this session
        final refreshed = await AuthService().getRememberedCredentials();
        _remembered = refreshed;
        if (kDebugMode) {
          print('🔄 AuthWrapper: Refreshed credentials - email: ${refreshed?.email ?? 'null'}');
        }
      }
      
      setState(() => _initialized = true);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing auth: $e');
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
        // Show loading indicator while the auth stream is establishing its initial state.
        // On cold starts (especially after swiping the app away), Firebase Auth may take
        // a moment to restore the persisted session.
        if (snapshot.connectionState == ConnectionState.waiting) {
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
          // On error, still check currentUser as fallback
          final fallbackUser = _auth.currentUser;
          if (fallbackUser == null) {
            return const LoginScreen();
          }
          // Continue with fallback user if available
        }

        // Check current user - Firebase Auth automatically persists auth state on mobile
        // Priority: snapshot.data (from stream) > currentUser (direct check)
        // This ensures we get the persisted auth state when app reopens
        var user = snapshot.data ?? _auth.currentUser;
        
        // If snapshot has no data but connection is active, double-check currentUser
        // This handles the case where the stream hasn't emitted yet but user exists
        if (user == null && snapshot.connectionState == ConnectionState.active) {
          user = _auth.currentUser;
          if (kDebugMode && user != null) {
            print('🔐 AuthWrapper: Stream empty but currentUser exists: ${user.uid}');
          }
        }

        // If user is not authenticated, show login screen
        if (user == null) {
          if (kDebugMode) {
            print('🔐 AuthWrapper: No authenticated user found - showing login');
          }
          final remembered = _remembered;
          return LoginScreen(
            initialEmail: remembered?.email,
            initialPassword: remembered?.password,
            initialRememberMe: remembered != null,
          );
        }

        // User is authenticated, check their profile
        if (kDebugMode) {
          print('🔐 AuthWrapper: User authenticated: ${user.uid}, Email: ${user.email}');
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
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          userSnapshot.hasError
                              ? 'Unable to load your profile right now. Please check your connection and try again.'
                              : 'Setting up your profile. Please try again.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
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