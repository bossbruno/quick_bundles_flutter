import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quick_bundles_flutter/main.dart';
import 'package:quick_bundles_flutter/screens/auth_wrapper.dart';

class MTNPage extends StatefulWidget {
  const MTNPage({super.key});

  @override
  State<MTNPage> createState() => _MTNPageState();
}

class _MTNPageState extends State<MTNPage> {
  @override
  void initState() {
    super.initState();
    Timer(
      const Duration(milliseconds: 500),
      () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Full-screen image
                Image.asset(
                  'assets/img_2.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}