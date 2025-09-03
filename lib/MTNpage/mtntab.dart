import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

class MtnScreen extends StatefulWidget {
  const MtnScreen({Key? key}) : super(key: key);

  @override
  State<MtnScreen> createState() => _MtnScreenState();
}

class _MtnScreenState extends State<MtnScreen> {

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to initiate call.'),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Phone permission required to place calls.')),
              );
              return;
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
      {'text': 'MTN CREDIT BALANCE \n *124#', 'ussdCode': '*124#'},
      {'text': 'MTN MOBILE MONEY \n *170#', 'ussdCode': '*170#'},
      {'text': 'MTN DATA INFO \n *156#', 'ussdCode': '*156#'},
      {'text': 'MTN ZONE \n *135#', 'ussdCode': '*135#'},
      {'text': 'MTN CUSTOMER SERVICE \n 100', 'ussdCode': '100'},
      {'text': 'MTN MASHUP/PULSE \n *567#', 'ussdCode': '*567#'},
      {'text': 'MTN BEST OFFERS \n *550#', 'ussdCode': '*550#'},
      {'text': 'MTN CHECK YOUR NUMBER \n *156#', 'ussdCode': '*156#'},
      {'text': 'REPORT MOMO FRAUD \n 1515', 'ussdCode': '1515'},
      {'text': 'CHECK IF SIM IS REGISTERED \n *400#', 'ussdCode': '*400#'},
    ];

    return Scaffold( // Added Scaffold for better structure
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.amber, Colors.white],
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




//
//
// import 'package:flutter/material.dart';
// import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
//
// class MtnScreen extends StatefulWidget {
//   const MtnScreen({super.key});
//
//   @override
//   State<MtnScreen> createState() => _MtnScreenState();
// }
//
// class _MtnScreenState extends State<MtnScreen> {
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     Widget buildButton(String text, String ussdCode) {
//       return Padding(
//         padding: const EdgeInsets.fromLTRB(15, 20, 15, 1),
//         child: ElevatedButton(
//           onPressed: () {
//             FlutterPhoneDirectCaller.callNumber(ussdCode);
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.white,
//             foregroundColor: Colors.black,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//             fixedSize: const Size(350, 50),
//           ),
//           child: Text(
//             text,
//             textAlign: TextAlign.center,
//           ),
//         ),
//       );
//     }
//
//     List<String> buttonTexts = [
//       'MTN CREDIT BALANCE \n *124#',
//       'MTN MOBILE MONEY \n *170#',
//       'MTN DATA INFO \n *156#',
//       'MTN ZONE \n *135#',
//       'MTN CUSTOMER SERVICE \n 100',
//       'MTN MASHUP/PULSE \n *567#',
//       'MTN BEST OFFERS \n *550#',
//       'MTN CHECK YOUR NUMBER \n *156#',
//       'REPORT MOMO FRAUD \n 1515',
//       'CHECK IF SIM IS REGISTERED \n *400#'
//
//       // ...
//     ];
//
//     List<String> ussdCodes = [
//       '*124#',
//       '*170#',
//       '*156#',
//       '*135#',
//       '100',
//       '*567#',
//       '*550#',
//       '*170#',
//       '1515',
//       '*400#',
//
//       // ...
//     ];
//     return SizedBox(
//
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
//         child: Container(
//           decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                   begin: Alignment.bottomCenter,
//                   end: Alignment.topCenter,
//                   colors: [Colors.amber, Colors.white])
//           ),
//           child: ListView(
//             children: [
//               for (int i = 0; i < buttonTexts.length; i++)
//                 buildButton(buttonTexts[i], ussdCodes[i]),
//             ],
//           ),
//
//         ),
//       ),
//
//      );
//   }
// }