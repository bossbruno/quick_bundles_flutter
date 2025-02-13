import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class VodafoneScreen extends StatefulWidget {
  const VodafoneScreen({super.key});

  @override
  State<VodafoneScreen> createState() => _VodafoneScreenState();
}

class _VodafoneScreenState extends State<VodafoneScreen> {
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
      'TELECEL CREDIT BALANCE \n *124#',
      'TELECEL INFORMATION SERVICE \n *151#',
      'TELECEL CASH \n *110#',
      'CHECK YOUR NUMBER \n *172#',
      'TELECEL INTERNET PACKAGES \n *700#',
      'TELECEL INTERNET BALANCE \n *126#',
      'TELECEL MADE4ME \n *530#',
      'CHECK IF SIM IS REGISTERED \n *400#'
      // ...
    ];

    List<String> ussdCodes = [
      '*124#',
      '*151#',
      '*110#',
      '*172#',
      '*700#',
      '*126#',
      '*530#',
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
                  colors: [Colors.red, Colors.white])),
          child: ListView(
            children: [
              for (int i = 0; i < buttonTexts.length; i++)
                buildButton(buttonTexts[i], ussdCodes[i]),
            ],
          ),
        ),
      ), // )
    );
  }
}
