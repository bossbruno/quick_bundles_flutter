import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class TigoScreen extends StatefulWidget {
  const TigoScreen({super.key});

  @override
  State<TigoScreen> createState() => _TigoScreenState();
}

class _TigoScreenState extends State<TigoScreen> {
  @override
  Widget build(BuildContext context) {
    return   SizedBox(
      height: 30,
      child:
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
        child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.red, Colors.blue])),
          child: Column(
            children: <Widget>[
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*124#");

                },


                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,

                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT CHECK CREDIT BALANCE \n *124#'  ,textAlign: TextAlign.center,), ),




              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*110#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT CASH \n *110#'  ,textAlign: TextAlign.center),),




              ),

              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*111#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT INTERNET PACKAGES \n *110#'  ,textAlign: TextAlign.center),),




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

                  child:  const Text('AT CUSTOMER SERVICE \n 100'  ,textAlign: TextAlign.center),),




              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*703#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT CHECK YOUR NUMBER \n *703#'  ,textAlign: TextAlign.center),),




              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*533#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT BEST OFFERS \n *533#'  ,textAlign: TextAlign.center),),




              ),

              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*499#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT SPECIAL OFFERS \n *499#'  ,textAlign: TextAlign.center),),




              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*703#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT CHECK INTERNET BUNDLE AND BONUS \n *504#'  ,textAlign: TextAlign.center),),




              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*100#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('AT SELF-SERVICE \n *100#'  ,textAlign: TextAlign.center),),




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
    );
  }
}