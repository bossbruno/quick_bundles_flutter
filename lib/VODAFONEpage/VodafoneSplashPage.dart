import 'dart:async';
import 'package:flutter/material.dart';
import '../AIRTELTIGOpage/AirtelSplashPage.dart';

class VodafonePage extends StatefulWidget {
  const VodafonePage({super.key});

  @override
  State<VodafonePage> createState() => _VodafonePageState();
}

class _VodafonePageState extends State<VodafonePage> {
  @override
  void initState() {
    super.initState();
    Timer(
      const Duration(seconds: 1),
      () => Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (BuildContext context) => const AirtelPage()
      ))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[Image.asset('assets/img.png')],
            ),
          ),
        ),
      ),
    );
  }
}