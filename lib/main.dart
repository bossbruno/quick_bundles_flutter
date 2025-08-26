import 'dart:async';
import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:quick_bundles_flutter/MTNpage/mtntab.dart';
import 'package:quick_bundles_flutter/VODAFONEpage/telecel_tab.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quick_bundles_flutter/VODAFONEpage/VodafoneSplashPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth_wrapper.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/firebase/firebase_init.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/onesignal_service.dart';
import 'services/fcm_v1_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'AIRTELTIGOpage/at_tab.dart';
import 'Ads_directory/ad_mob_service.dart';
import 'services/shared_preference_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Shared Preferences
  final sharedPrefs = BambooSharedPreference();
  await sharedPrefs.init();
  
  // Initialize the app
  runApp(const MyApp());

  // Fire-and-forget ancillary initializations to avoid startup jank
  unawaited(MobileAds.instance.initialize());
  unawaited(OneSignalService.initialize());
  unawaited(FCMV1Service().initialize());

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  unawaited(flutterLocalNotificationsPlugin.initialize(initializationSettings));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Bundles Ghana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFFFB300), // Ghana gold
          primary: Color(0xFFFFB300), // Ghana gold
          secondary: Color(0xFF43A047), // Ghana green
          background: Color(0xFFF9F9F9),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Color(0xFFF9F9F9),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFFFB300),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFFFB300),
            shape: StadiumBorder(),
            textStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFFFB300)),
          ),
        ),
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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AdMobService.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {});
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );
    await _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Widget _buildHomeTabs() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
          appBar: AppBar(
          title: const Text("Q U I C K  B U N D L E S"),
            centerTitle: true,
          ),
        body: Column(
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
                    ],
                  ),
      ),
    );
  }

  Widget _buildLoginPage() {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: user == null
          ? AppBar(
        title: const Text('Login'),
        centerTitle: true,
            )
          : null,
      body: const Column(
        children: [
          Expanded(child: AuthWrapper()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent;
    if (_selectedIndex == 0) {
      mainContent = _buildHomeTabs();
    } else {
      mainContent = _buildLoginPage();
    }

    return Scaffold(
      body: SafeArea(child: mainContent),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store),
                label: 'Marketplace',
              ),
            ],
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
    );
  }
}

