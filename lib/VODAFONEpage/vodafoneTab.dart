import 'dart:async';

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
    return SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.red, Colors.white])),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*126#");
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),
                  child: const Text(
                    'VODAFONE CHECK CREDIT BALANCE \n *126#',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*151#");
                  },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child: const Text('VODAFONE INFORMATION SERVICE \n *151#',
                      textAlign: TextAlign.center),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*126#");
                  },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child: const Text('CHECK BUNDLE BALANCE \n *126#',
                      textAlign: TextAlign.center),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*110#");
                  },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child: const Text('VODAFONE CASH \n *110#',
                      textAlign: TextAlign.center),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*127#");
                  },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child: const Text('CHECK YOUR NUMBER \n *127#',
                      textAlign: TextAlign.center),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*700#");
                  },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child: const Text('VODAFONE INTERNET PACKAGES \n *700#',
                      textAlign: TextAlign.center),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*530#");
                  },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child: const Text('VODAFONE MADEFORME BUNDLES \n *530#',
                      textAlign: TextAlign.center),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}