import 'dart:async';
import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:quick_bundles_flutter/MTNpage/mtntab.dart';
import 'package:quick_bundles_flutter/VODAFONEpage/telecel_tab.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

// Local imports
import 'screens/auth_wrapper.dart';
import 'VODAFONEpage/VodafoneSplashPage.dart';
import 'services/favorites_service.dart';
import 'core/firebase/firebase_init.dart';
import 'services/onesignal_service.dart';
import 'services/fcm_v1_service.dart';
import 'services/notification_service.dart';
import 'AIRTELTIGOpage/at_tab.dart';
import 'Ads_directory/ad_mob_service.dart';
import 'services/auth_service.dart';

// Initialize notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  try {
    // Ensure Flutter binding is initialized
    WidgetsFlutterBinding.ensureInitialized();
    
    if (kDebugMode) {
      print('🚀 Starting app initialization...');
    }

    // 1. Load environment variables first
    try {
      await dotenv.load(fileName: ".env");
      if (kDebugMode) {
        print('✅ Environment variables loaded');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to load environment variables: $e');
      }
    }
    
    // 2. Initialize Firebase with error handling
    try {
      await FirebaseInit.initialize();
      if (kDebugMode) {
        print('✅ Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize Firebase: $e');
      }
      // Continue running the app even if Firebase fails
    }
    
    // 3. Initialize AuthService and check/create user profile if needed
    try {
      final authService = AuthService();
      await authService.checkAndCreateUserProfile();
      if (kDebugMode) {
        print('✅ User profile check completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ User profile check failed: $e');
      }
    }
    
    // 4. Initialize notifications and messaging services
    try {
      await _initializeNotificationsAndAds();
      
      // Initialize OneSignal
      await OneSignalService.initialize();
      await NotificationService().saveOneSignalPlayerId();
      
      if (!kIsWeb) {
        try {
          final notificationService = NotificationService();
          await notificationService.initialize();
          
          final fcmService = FCMV1Service();
          await fcmService.initialize();
          
          if (kDebugMode) {
            print('✅ FCM services initialized');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ FCM initialization failed: $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('✅ Notification services initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to initialize notification services: $e');
      }
    }
    
    // 5. Initialize Mobile Ads (non-blocking)
    if (!kIsWeb) {
      try {
        await MobileAds.instance.initialize();
        if (kDebugMode) {
          print('✅ Mobile Ads initialized');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to initialize Mobile Ads: $e');
        }
      }
    }
    
    // 6. Initialize SharedPreferences and FavoritesService
    try {
      await FavoritesService().init();
      if (kDebugMode) {
        print('✅ Favorites service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to initialize Favorites service: $e');
      }
    }
    
    if (kDebugMode) {
      print('Firebase Project ID: ${dotenv.env['FIREBASE_PROJECT_ID'] ?? 'Not found'}');
      print('🚀 App initialization complete, running app...');
    }
     
    // Run the app
    runApp(const MyApp());
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ Fatal error during app initialization: $e');
      print('Stack trace: $stackTrace');
    }
    
    // Show error UI
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Please restart the app or contact support if the problem persists.'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _initializeNotificationsAndAds() async {
  try {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    if (!kIsWeb) {
      // Android 13+ notification permission request at runtime
      if (defaultTargetPlatform == TargetPlatform.android) {
        final FirebaseMessaging messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      }
    }
  } catch (_) {}

  // Initialize Mobile Ads after permissions and (later) consent
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
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

