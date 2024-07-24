import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:selfdesignqb2/MTNpage/mtntab.dart';
import 'package:selfdesignqb2/VODAFONEpage/telecel_tab.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


import 'AIRTELTIGOpage/at_tab.dart';
import 'Ads_directory/ad_mob_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize().then((InitializationStatus status) {
    print('Initialization complete: ${status.adapterStatuses}');
    runApp(const HomePage());
  }).catchError((error) {
    print('Error initializing Mobile Ads: $error');
    // Handle the error appropriately, e.g., display a message to the user.
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePage();
}
class _HomePage extends State<HomePage> {
  BannerAd? _bannerAd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AdMobService.bannerAdUnitId, // Use your AdMobService
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {}); // Refresh the UI to show the ad
        },
        onAdFailedToLoad: (ad, error) {
          print('Failed to load banner ad: ${error.message}');
          ad.dispose();
        },
      ),request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // Dispose the banner ad when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


    return MaterialApp(
     //home: Directionality(textDirection: TextDirection.rtl,
      home:DefaultTabController(
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
                    Tab(text: ("TELECEL")),
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
                ),
                if (_bannerAd != null)
                  Container( // Wrap the AdWidget in a Container for alignment
                    alignment: Alignment.center, // Center the ad horizontally
                    width: _bannerAd!.size.width.toDouble(),height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          )

      ),
    )
    )
    ;
  }}

