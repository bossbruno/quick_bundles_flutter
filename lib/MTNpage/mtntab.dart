import 'dart:async';

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
    return SizedBox(
     // height: 30,
      child: SingleChildScrollView(

      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.amber, Colors.white])),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*124#");
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
                    'MTN CHECK CREDIT BALANCE \n *124#',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(
                  onPressed: () {
                    FlutterPhoneDirectCaller.callNumber("*135*2*1#");
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

                  child: const Text('MTN ZONE CHECK BALANCE \n *135*2*2#',
                      textAlign: TextAlign.center),
                ),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*135*2*2#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('MTN MOBILE MONEY \n *170#'  ,textAlign: TextAlign.center),),
              ),
        Padding(
          padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
          child: ElevatedButton(onPressed: () {
            FlutterPhoneDirectCaller.callNumber("*170#");
          },
            // icon:const Icon(Icons.call),

            style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                // StadiumBorder(),

                fixedSize: const Size(350, 50)),

            child:  const Text('MTN MOBILE MONEY \n *170#'  ,textAlign: TextAlign.center),),
        ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("100");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('MTN CUSTOMER SERVICE \n 100'  ,textAlign: TextAlign.center),),




              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*567#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('MTN MASHUP/PULSE \n *567#'  ,textAlign: TextAlign.center),),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*550#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('MTN OFFERS \n *550#'  ,textAlign: TextAlign.center),),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*156#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('CHECK YOUR NUMBER \n *170#'  ,textAlign: TextAlign.center),),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("1515");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('REPORT MOMO FRAUD \n 1515'  ,textAlign: TextAlign.center),),
              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*400#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('CHECK IF SIM IS REGISTERED \n *400#'  ,textAlign: TextAlign.center),),
              ),

            ],
          ),
        ),
      ),

    ),
     );
  }
}