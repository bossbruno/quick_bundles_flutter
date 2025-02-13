import 'dart:async';

import 'package:flutter/material.dart';

import '../MTNpage/MtnSplashpage.dart';

class AirtelPage extends StatefulWidget {
  const AirtelPage({super.key});

  @override
  State<AirtelPage> createState() => _AirtelPageState();
}

class _AirtelPageState extends State<AirtelPage> {
  @override
  void initState() {
    // TODO: implement initState
    Timer(
        const Duration(seconds:1),
            () => Navigator.of(context).push(MaterialPageRoute(
            builder: (BuildContext context) => const MTNPage())));
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    // Figma Flutter Generator Group1Widget - GROUP
    return MaterialApp(
        home: SafeArea(
          child: Scaffold(
            body: Center(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[Image.asset('assets/img_1.png')],
                ),
              ),
            ),
          ),
        ));
  }
}