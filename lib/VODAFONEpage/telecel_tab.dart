import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

class VodafoneScreen extends StatefulWidget {
  const VodafoneScreen({super.key});

  @override
  State<VodafoneScreen> createState() => _VodafoneScreenState();
}

class _VodafoneScreenState extends State<VodafoneScreen> {
  // @override
  // void initState() {
  //   super.initState();
  // }

  // Moved button creation logic to a separate method for better organization.
  Widget _buildButton(String text, String ussdCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), // Simplified padding
      child: ElevatedButton(
        onPressed: () async {
          // Added error handling and await for better control.
          try {
            if (await Permission.phone.request().isGranted) {
              bool? res = await FlutterPhoneDirectCaller.callNumber(ussdCode);
              if (res == false) {
                // Handle the case where the call failed to initiate.
                if (mounted) { // Check if the widget is still in the tree
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to initiate call.'),
                    ),
                  );
                }
              }
            } else {
              // Handle the case where the call failed to initiate.
              if (mounted) { // Check if the widget is still in the tree
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone permission required to place calls.')),
                );
              }
              return;
            }
          } catch (e) {
            // Handle any exceptions that might occur during the call.
            if (mounted) { // Check if the widget is still in the tree
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error during call: $e'),
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: const Size(350, 50), // Use minimumSize instead of fixedSize
          padding: const EdgeInsets.all(10), // Add padding to the button content
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16), // Added a font size for better readability
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using a map to associate text and USSD codes for better readability and maintainability.
    final List<Map<String, String>> buttonData = [
      {'text': 'TELECEL CREDIT BALANCE \n *124#', 'ussdCode': '*124#'},
      {'text': 'TELECEL CASH \n *110#', 'ussdCode': '*110#'},
      {'text': 'TELECEL INFORMATION SERVICE \n *151#', 'ussdCode': '*151#'},
      {'text': 'TELECEL INTERNET PACKAGES \n *700#', 'ussdCode': '*700#'},
      {'text': 'TELECEL CUSTOMER SERVICE \n 100', 'ussdCode': '100'},
      {'text': 'TELECEL INTERNET BALANCE \n *126#', 'ussdCode': '*126#'},
      {'text': 'TELECEL MADE4ME \n *530#', 'ussdCode': '*530#'},
      {'text': 'TELECEL CHECK YOUR NUMBER \n *127#', 'ussdCode': '*127#'},
      {'text': 'CHECK IF SIM IS REGISTERED \n *400#', 'ussdCode': '*400#'},
    ];

    return Scaffold( // Added Scaffold for better structure
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.red, Colors.white],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 10), // Added padding to the top of the list
          itemCount: buttonData.length,
          itemBuilder: (context, index) {
            final data = buttonData[index];
            return _buildButton(data['text']!, data['ussdCode']!);
          },
        ),
      ),
    );
  }
}





























// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
// import 'dart:io' show Platform;
// import 'package:url_launcher/url_launcher.dart';
//
// class VodafoneScreen extends StatefulWidget {
//   const VodafoneScreen({super.key});
//
//   @override
//   State<VodafoneScreen> createState() => _VodafoneScreenState();
// }
//
// class _VodafoneScreenState extends State<VodafoneScreen> {
//   Future<void> _handleCall(String ussdCode) async {
//     if (Platform.isIOS && (ussdCode.contains("*") || ussdCode.contains("#"))) {
//       // iOS can't dial USSD directly — copy and open empty dialer
//       await Clipboard.setData(ClipboardData(text: ussdCode));
//       if (await canLaunchUrl(Uri.parse("tel://"))) {
//         await launchUrl(Uri.parse("tel://"));
//       }
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('USSD code copied! Paste it into the dialer.'),
//           ),
//         );
//       }
//     } else {
//       // Android or direct number (e.g., 100)
//       try {
//         bool? res = await FlutterPhoneDirectCaller.callNumber(ussdCode);
//         if (res == false && mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Failed to initiate call.')),
//           );
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error during call: $e')),
//           );
//         }
//       }
//     }
//   }
//
//   Widget _buildButton(String text, String ussdCode) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
//       child: ElevatedButton(
//         onPressed: () => _handleCall(ussdCode),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.white,
//           foregroundColor: Colors.black,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           minimumSize: const Size(350, 50),
//           padding: const EdgeInsets.all(10),
//         ),
//         child: Text(
//           text,
//           textAlign: TextAlign.center,
//           style: const TextStyle(fontSize: 16),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final List<Map<String, String>> buttonData = [
//       {'text': 'TELECEL CREDIT BALANCE \n *124#', 'ussdCode': '*124#'},
//       {'text': 'TELECEL CASH \n *110#', 'ussdCode': '*110#'},
//       {'text': 'TELECEL INFORMATION SERVICE \n *151#', 'ussdCode': '*151#'},
//       {'text': 'TELECEL INTERNET PACKAGES \n *700#', 'ussdCode': '*700#'},
//       {'text': 'TELECEL CUSTOMER SERVICE \n 100', 'ussdCode': '100'},
//       {'text': 'TELECEL INTERNET BALANCE \n *126#', 'ussdCode': '*126#'},
//       {'text': 'TELECEL MADE4ME \n *530#', 'ussdCode': '*530#'},
//       {'text': 'TELECEL CHECK YOUR NUMBER \n *127#', 'ussdCode': '*127#'},
//       {'text': 'CHECK IF SIM IS REGISTERED \n *400#', 'ussdCode': '*400#'},
//     ];
//
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.bottomCenter,
//             end: Alignment.topCenter,
//             colors: [Colors.red, Colors.white],
//           ),
//         ),
//         child: ListView.builder(
//           padding: const EdgeInsets.only(top: 10),
//           itemCount: buttonData.length,
//           itemBuilder: (context, index) {
//             final data = buttonData[index];
//             return _buildButton(data['text']!, data['ussdCode']!);
//           },
//         ),
//       ),
//     );
//   }
// }
