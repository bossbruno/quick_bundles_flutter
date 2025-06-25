import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';

class MTNPage extends StatefulWidget {
  const MTNPage({super.key});

  @override
  State<MTNPage> createState() => _MTNPageState();
}

class _MTNPageState extends State<MTNPage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(
        const Duration(seconds: 1),
            () => Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (BuildContext context) => const HomePage())));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[Image.asset('assets/img_2.png')],
                ),
              ),
            ),
          ),
    );
  }
}