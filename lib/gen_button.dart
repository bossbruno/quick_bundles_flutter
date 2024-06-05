import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';


class GeneralButton extends StatelessWidget {
  final String text;
  final String ussdCode;

  const GeneralButton({super.key, 
    required this.text,
    required this.ussdCode,
  });

  @override
  Widget build(BuildContext context) {
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
}