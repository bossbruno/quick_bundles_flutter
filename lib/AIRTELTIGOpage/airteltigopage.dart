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

                  child:  const Text('TIGO CHECK CREDIT BALANCE \n *124#'  ,textAlign: TextAlign.center,), ),




              ),
              Padding(
                padding:const EdgeInsets.fromLTRB(1, 20, 1, 1),
                child: ElevatedButton(onPressed: () {
                  FlutterPhoneDirectCaller.callNumber("*135*2*1#");
                },
                  // icon:const Icon(Icons.call),

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),),
                      // StadiumBorder(),

                      fixedSize: const Size(350, 50)),

                  child:  const Text('TIGO CASH \n *110#'  ,textAlign: TextAlign.center),),




              ),

            ],
          ),

        ),


      ),
    );
  }
}