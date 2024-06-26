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
      'TELECEL CREDIT BALANCE',
      'TELECEL INFORMATION SERVICE',
      'TELECEL CASH',
      'CHECK YOUR NUMBER',
      'TELECEL INTERNET PACKAGES',
      'TELECEL INTERNET BALANCE',
      'TELECEL MADE4ME',
      'CHECK IF SIM IS REGISTERED'
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
