import 'package:flutter/material.dart';
//import 'package:firebase_admob/firebase_admob.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class TigoScreen extends StatefulWidget {
  const TigoScreen({super.key});

  @override
  State<TigoScreen> createState() => _TigoScreenState();
}

class _TigoScreenState extends State<TigoScreen> {

  // Moved button creation logic to a separate method for better organization.
  Widget _buildButton(String text, String ussdCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), // Simplified padding
      child: ElevatedButton(
        onPressed: () async {
          // Added error handling and await for better control.
          try {
            bool? res = await FlutterPhoneDirectCaller.callNumber(ussdCode);
            if (res == false) {
              // Handle the case where the call failed to initiate.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to initiate call.'),
                ),
              );
            }
          } catch (e) {
            // Handle any exceptions that might occur during the call.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error during call: $e'),
              ),
            );
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
      {'text': 'AT CREDIT BALANCE \n *124#', 'ussdCode': '*124#'},
      {'text': 'AT BUNDLE BALANCE \n *504#', 'ussdCode': '*504#'},
      {'text': 'AT MONEY \n *110#', 'ussdCode': '*110#'},
      {'text': 'AT INTERNET PACKAGES \n *111#', 'ussdCode': '*111#'},
      {'text': 'AT BEST OFFERS \n *533#', 'ussdCode': '*533#'},
      {'text': 'AT CUSTOMER SERVICE \n 100', 'ussdCode': '100'},
      {'text': 'AT SELF SERVICE \n *100#', 'ussdCode': '*100#'},
      {'text': 'AT SPECIAL OFFERS \n *499#', 'ussdCode': '*499#'},
      {'text': 'AT CHECK YOUR NUMBER \n *703#', 'ussdCode': '*703#'},
      {'text': 'CHECK IF SIM IS REGISTERED \n *400#', 'ussdCode': '*400#'},
    ];

    return Scaffold( // Added Scaffold for better structure
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.red, Colors.blue],
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
