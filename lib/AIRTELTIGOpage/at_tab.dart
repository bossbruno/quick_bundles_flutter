import 'package:flutter/material.dart';
//import 'package:firebase_admob/firebase_admob.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class TigoScreen extends StatefulWidget {
  const TigoScreen({super.key});

  @override
  State<TigoScreen> createState() => _TigoScreenState();
}

class _TigoScreenState extends State<TigoScreen> {

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
      'AT CREDIT BALANCE \n *124#',
      'AT MONEY \n *110#',
      'AT INTERNET PACKAGES \n *111#',
      'AT CUSTOMER SERVICE \n 100',
      'CHECK YOUR NUMBER \n *703#',
      'AT BEST OFFERS \n *533#',
      'AT SPECIAL OFFERS\n *499#',
      'AT BUNDLE BALANCE\n *504#',
      'AT SELF SERVICE\n *100#',
      'CHECK IF SIM IS REGISTERED\n *400#'

      // ...
    ];

    List<String> ussdCodes = [
      '*124#',
      '*110#',
      '*111#',
      '100',
      '*703#',
      '*533#',
      '*499#',
      '*504#',
      '*100#',
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
                  colors: [Colors.red, Colors.blue])),
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
