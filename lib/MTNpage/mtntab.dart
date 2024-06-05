

import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class MtnScreen extends StatefulWidget {
  const MtnScreen({super.key});

  @override
  State<MtnScreen> createState() => _MtnScreenState();
}

class _MtnScreenState extends State<MtnScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget buildButton(String text, String ussdCode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(15, 20, 15, 1),
        child: ElevatedButton(
          onPressed: () {
            FlutterPhoneDirectCaller.callNumber(ussdCode);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            fixedSize: const Size(350, 50),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    List<String> buttonTexts = [
      'MTN CREDIT BALANCE',
      'MTN MOBILE MONEY',
      'MTN ZONE',
      'MTN CUSTOMER SERVICE',
      'MTN MASHUP/PULSE',
      'MTN BEST OFFERS',
      'MTN CHECK YOUR NUMBER',
      'REPORT MOMO FRAUD',
      'CHECK IF SIM IS REGISTERED'

      // ...
    ];

    List<String> ussdCodes = [
      '*124#',
      '*170#',
      '*135#',
      '100',
      '*567#',
      '*550#',
      '*170#',
      '1515',
      '*400#'
      // ...
    ];
    return SizedBox(

      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.amber, Colors.white])
          ),
          child: ListView(
            children: [
              for (int i = 0; i < buttonTexts.length; i++)
                buildButton(buttonTexts[i], ussdCodes[i]),
            ],
          ),

        ),
      ),

     );
  }
}