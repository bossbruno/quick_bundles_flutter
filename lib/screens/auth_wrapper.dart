import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/marketplace/screens/marketplace_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/vendor/screens/vendor_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                // Show error message and sign out
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User profile not found. Please try logging in again.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  // Sign out the user
                  FirebaseAuth.instance.signOut();
                });
                return const LoginScreen();
              }

              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final userType = userData?['userType'] ?? 'user';
              
              if (userType == 'vendor') {
                return const VendorDashboardScreen();
              } else {
                return const MarketplaceScreen();
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
} 