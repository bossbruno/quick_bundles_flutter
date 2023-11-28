import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

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
            padding: const EdgeInsets.all(8.0),
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
                Expanded(
                  child: TabBarView(
                    children: [
                      SizedBox(
                        height: 30,
                        child:
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
                          child: Container(
                            decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.amber, Colors.white])),
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

                                    child:  const Text('MTN CHECK CREDIT BALANCE \n *124#'  ,textAlign: TextAlign.center,), ),




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

                                    child:  const Text('MTN ZONE BUNDLES \n *135*2*1#'  ,textAlign: TextAlign.center),),




                                ),

                              ],
                            ),

                          ),


                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(1, 30, 1, 1),
                        child: Container(
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.red, Colors.white])),

                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(1, 30, 1, 1),
                        child: Container(
                            decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.red, Colors.blueAccent])),
                            child: Column(
                              children: <Widget>[

                                ElevatedButton(onPressed: () {}, child: const Text('TIGO CHECK CREDIT BALANCE')),
                                TextButton(onPressed: () {}, child: Text('hi')),

                              ],
                            )


                        ),
                      ),


                    ],
                  ),
                )
              ],
            ),
          )),
    );
  }
}