import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:selfdesignqb2/MTNpage/mtntab.dart';
import 'package:selfdesignqb2/VODAFONEpage/vodafoneTab.dart';

import 'AIRTELTIGOpage/airteltigopage.dart';

void main() {
  runApp(const HomePage());
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
          appBar: AppBar(
            title: const Text("Q U I C K  B U N D L E S "),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Column(
              children: [
                ButtonsTabBar(
                  // height: 45,
                  // decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(30)),

                  //  padding: const EdgeInsets.all(8.0),
                  borderWidth: 2,
                  buttonMargin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  radius: (100),
                  splashColor: Colors.blueAccent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),

                  backgroundColor: Colors.blue[600],
                  unselectedBackgroundColor: Colors.white,
                  labelStyle: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'assets/Poppins-ExtraBold.tff',
                      fontWeight: FontWeight.bold),
                  unselectedBorderColor: Colors.blue,

                  tabs: const [
                    Tab(text: ("    MTN    ")),
                    Tab(text: ("VODAFONE")),
                    Tab(text: ("    TIGO    ")),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [

                      //MTN TAB
                      MtnScreen(),

                      //VodafoneTab
                      VodafoneScreen(),

                      //AIRTELTIGO
                      TigoScreen(),


                    ],
                  ),
                )
              ],
            ),
          )),
    );
  }
}