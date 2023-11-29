import 'dart:async';
import 'package:flutter/material.dart';

import '../AIRTELTIGOpage/AirtelSpl;ashPage.dart';


void main() {
  runApp(const Myapp());
}

class Myapp extends StatelessWidget {
  const Myapp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: VodafonePage(),
    );
  }
}

class VodafonePage extends StatefulWidget {
  const VodafonePage({super.key});

  @override
  State<VodafonePage> createState() => _VodafonePageState();
}

class _VodafonePageState extends State<VodafonePage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(
        const Duration(seconds: 1),
            () => Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (BuildContext context) => const AirtelPage())));
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
        home: SafeArea(
          child: Scaffold(
            body: Center(
              child:SingleChildScrollView (

              child: Column(
                children: <Widget>[Image.asset('assets/img.png')],

              ),

            ),
          ),
          ),
        )
    );
  }
}