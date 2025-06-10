import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:quick_bundles_flutter/MTNpage/mtntab.dart';
import 'package:quick_bundles_flutter/VODAFONEpage/telecel_tab.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quick_bundles_flutter/VODAFONEpage/VodafoneSplashPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth_wrapper.dart';
import 'firebase_options.dart';

import 'core/firebase/firebase_init.dart';
import 'features/auth/screens/login_screen.dart';

import 'AIRTELTIGOpage/at_tab.dart';
import 'Ads_directory/ad_mob_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  MobileAds.instance.initialize().then((InitializationStatus status) {
    print('Initialization complete: ${status.adapterStatuses}');
    runApp(const MyApp());
  }).catchError((error) {
    print('Error initializing Mobile Ads: $error');
    // Handle the error appropriately, e.g., display a message to the user.
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Bundles',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const VodafonePage(),
    );
  }
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
      adUnitId: AdMobService.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          print('Failed to load banner ad: ${error.message}');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Q U I C K  B U N D L E S"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.login),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Column(
              children: [
                ButtonsTabBar(
                  borderWidth: 2,
                  buttonMargin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  radius: (100),
                  splashColor: Colors.blueAccent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  backgroundColor: Colors.blue[600],
                  unselectedBackgroundColor: Colors.white,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'assets/Poppins-ExtraBold.tff',
                    fontWeight: FontWeight.bold
                  ),
                  unselectedBorderColor: Colors.blue,
                  tabs: const [
                    Tab(text: ("    MTN    ")),
                    Tab(text: ("TELECEL")),
                    Tab(text: ("    AT    ")),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      MtnScreen(),
                      VodafoneScreen(),
                      TigoScreen(),
                    ],
                  ),
                ),
                if (_bannerAd != null)
                  Container(
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

