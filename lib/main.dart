import 'dart:async';
import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:quick_bundles_flutter/MTNpage/mtntab.dart';
import 'package:quick_bundles_flutter/VODAFONEpage/telecel_tab.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quick_bundles_flutter/VODAFONEpage/VodafoneSplashPage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/favorites_service.dart';
import 'core/firebase/firebase_init.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/onesignal_service.dart';
import 'services/fcm_v1_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'AIRTELTIGOpage/at_tab.dart';
import 'Ads_directory/ad_mob_service.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';

import 'features/auth/screens/signup_screen.dart';
import 'core/theme_provider.dart';
import 'core/app_theme.dart';
import 'package:provider/provider.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  try {
    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables
    await dotenv.load(fileName: ".env");
    
    // Initialize Firebase only if it hasn't been initialized yet
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Firebase initialization error: $e');
      }
    }
    
    // Initialize notifications and ads
    await _initializeNotificationsAndAds();
    
    // Initialize AuthService and check/create user profile if needed
    final authService = AuthService();
    await authService.checkAndCreateUserProfile();
    
    // Initialize OneSignal
    await OneSignalService.initialize();
    
    // Initialize FCM if not in web
    if (!kIsWeb) {
      try {
        // Initialize NotificationService to register FCM handlers and save token
        await NotificationService().initialize();
        final fcmService = FCMV1Service();
        await fcmService.initialize();
      } catch (e) {
        if (kDebugMode) {
          print('FCM initialization error: $e');
        }
      }
    }
    
    // Initialize SharedPreferences and FavoritesService
    await FavoritesService().init();
    
    // Initialize FirebaseInit (Custom wrapper if used)
    await FirebaseInit.initialize();
    
    // Run the app with ThemeProvider
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );
    
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing app: $e');
    }
    rethrow;
  }
}

Future<void> _initializeNotificationsAndAds() async {
  try {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final FirebaseMessaging messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    }
  } catch (_) {}

  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Quick Bundles Ghana',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const VodafonePage(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
          },
        );
      },
    );
  }
}
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AuthWrapper(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
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
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          title: const Text("QUICK BUNDLES"),
          centerTitle: true,
          actions: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return IconButton(
                  icon: Icon(
                    themeProvider.themeMode == ThemeMode.dark 
                      ? Icons.dark_mode : Icons.light_mode,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                  tooltip: 'Toggle Theme',
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ButtonsTabBar(
                backgroundColor: Colors.white,
                unselectedBackgroundColor: Colors.white.withOpacity(0.2),
                unselectedLabelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                labelStyle: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                borderWidth: 0,
                radius: 100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [
                  Tab(text: "  MTN  "),
                  Tab(text: "TELECEL"),
                  Tab(text: "   AT   "),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            MtnScreen(),
            VodafoneScreen(),
            TigoScreen(),
          ],
        ),
      ),
    );
  }
}
