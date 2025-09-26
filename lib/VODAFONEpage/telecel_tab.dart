import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_bundles_flutter/models/shortcode_model.dart';
import 'package:quick_bundles_flutter/widgets/shortcode_card.dart';
import 'package:quick_bundles_flutter/services/favorites_service.dart';

class VodafoneScreen extends StatefulWidget {
  const VodafoneScreen({super.key});

  @override
  State<VodafoneScreen> createState() => _VodafoneScreenState();
}

class _VodafoneScreenState extends State<VodafoneScreen> {
  final List<Shortcode> _shortcodes = [
    Shortcode(
      id: 'telecel_balance',
      title: 'Balance Check',
      code: '*124#',
      description: 'Check your current airtime balance',
      network: NetworkType.telecel,
      category: 'Account',
      icon: Icons.account_balance_wallet,
    ),
    Shortcode(
      id: 'telecel_info',
      title: 'Information Service',
      code: '*151#',
      description: 'Get Telecel service information',
      network: NetworkType.telecel,
      category: 'Support',
      icon: Icons.info,
    ),
    Shortcode(
      id: 'telecel_bundle_balance',
      title: 'Bundle Balance',
      code: '*126#',
      description: 'Check your data bundle balance',
      network: NetworkType.telecel,
      category: 'Data',
      icon: Icons.data_usage,
    ),
    Shortcode(
      id: 'telecel_cash',
      title: 'Telecel Cash',
      code: '*110#',
      description: 'Access Telecel Cash services',
      network: NetworkType.telecel,
      category: 'Mobile Money',
      icon: Icons.money,
    ),
    Shortcode(
      id: 'telecel_check_number',
      title: 'Check Number',
      code: '*127#',
      description: 'Check your phone number',
      network: NetworkType.telecel,
      category: 'Account',
      icon: Icons.phone_android,
    ),
    Shortcode(
      id: 'telecel_service',
      title: 'Customer Service',
      code: '100',
      description: 'Contact Telecel customer service',
      network: NetworkType.telecel,
      category: 'Support',
      icon: Icons.headset_mic,
    ),
    Shortcode(
      id: 'telecel_internet',
      title: 'Internet Packages',
      code: '*700#',
      description: 'Browse and buy internet packages',
      network: NetworkType.telecel,
      category: 'Data',
      icon: Icons.wifi,
    ),
    Shortcode(
      id: 'telecel_bundles',
      title: 'Made For Me Bundles',
      code: '*530#',
      description: 'Custom data bundles',
      network: NetworkType.telecel,
      category: 'Data',
      icon: Icons.smartphone,
    ),
    Shortcode(
      id: 'telecel_sim_registration',
      title: 'Check SIM Registration',
      code: '*400#',
      description: 'Check if your SIM is registered',
      network: NetworkType.telecel,
      category: 'Account',
      icon: Icons.sim_card,
    ),
    // Add more Telecel shortcodes as needed
  ];

  List<Shortcode> _filteredShortcodes = [];
  final TextEditingController _searchController = TextEditingController();

  final FavoritesService _favoritesService = FavoritesService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _favoritesService.init().then((_) {
        _loadShortcodes();
      });
    });
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadShortcodes() async {
    await _favoritesService.loadFavorites(_shortcodes);
    setState(() {
      _filteredShortcodes = List.from(_shortcodes);
      _sortShortcodes();
    });
  }

  void _sortShortcodes() {
    _filteredShortcodes.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return 0;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredShortcodes = _shortcodes.where((shortcode) {
        return shortcode.title.toLowerCase().contains(query) ||
            shortcode.code.contains(query) ||
            shortcode.description.toLowerCase().contains(query);
      }).toList();
      _sortShortcodes();
    });
  }

  Future<void> _toggleFavorite(String id) async {
    await _favoritesService.toggleFavorite(id);
    await _loadShortcodes();
  }

  Future<void> _dialShortcode(String code) async {
    try {
      if (await Permission.phone.request().isGranted) {
        bool? res = await FlutterPhoneDirectCaller.callNumber(code);
            if (res == false) {
          if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initiate call')),
                );
              }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone permission required')),
        );
            }
          } catch (e) {
      if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Telecel Shortcodes'),
        backgroundColor: Colors.red[900],
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search shortcodes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _filteredShortcodes.isEmpty
                ? const Center(
                    child: Text('No shortcodes found'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: _filteredShortcodes.length,
          itemBuilder: (context, index) {
                      final shortcode = _filteredShortcodes[index];
                      return ShortcodeCard(
                        shortcode: shortcode,
                        onTap: () => _dialShortcode(shortcode.code),
                        onFavoriteToggle: () => _toggleFavorite(shortcode.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}





























// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
// import 'dart:io' show Platform;
// import 'package:url_launcher/url_launcher.dart';
//
// class VodafoneScreen extends StatefulWidget {
//   const VodafoneScreen({super.key});
//
//   @override
//   State<VodafoneScreen> createState() => _VodafoneScreenState();
// }
//
// class _VodafoneScreenState extends State<VodafoneScreen> {
//   Future<void> _handleCall(String ussdCode) async {
//     if (Platform.isIOS && (ussdCode.contains("*") || ussdCode.contains("#"))) {
//       // iOS can't dial USSD directly — copy and open empty dialer
//       await Clipboard.setData(ClipboardData(text: ussdCode));
//       if (await canLaunchUrl(Uri.parse("tel://"))) {
//         await launchUrl(Uri.parse("tel://"));
//       }
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('USSD code copied! Paste it into the dialer.'),
//           ),
//         );
//       }
//     } else {
//       // Android or direct number (e.g., 100)
//       try {
//         bool? res = await FlutterPhoneDirectCaller.callNumber(ussdCode);
//         if (res == false && mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Failed to initiate call.')),
//           );
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error during call: $e')),
//           );
//         }
//       }
//     }
//   }
//
//   Widget _buildButton(String text, String ussdCode) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
//       child: ElevatedButton(
//         onPressed: () => _handleCall(ussdCode),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.white,
//           foregroundColor: Colors.black,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           minimumSize: const Size(350, 50),
//           padding: const EdgeInsets.all(10),
//         ),
//         child: Text(
//           text,
//           textAlign: TextAlign.center,
//           style: const TextStyle(fontSize: 16),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final List<Map<String, String>> buttonData = [
//       {'text': 'TELECEL CREDIT BALANCE \n *124#', 'ussdCode': '*124#'},
//       {'text': 'TELECEL CASH \n *110#', 'ussdCode': '*110#'},
//       {'text': 'TELECEL INFORMATION SERVICE \n *151#', 'ussdCode': '*151#'},
//       {'text': 'TELECEL INTERNET PACKAGES \n *700#', 'ussdCode': '*700#'},
//       {'text': 'TELECEL CUSTOMER SERVICE \n 100', 'ussdCode': '100'},
//       {'text': 'TELECEL INTERNET BALANCE \n *126#', 'ussdCode': '*126#'},
//       {'text': 'TELECEL MADE4ME \n *530#', 'ussdCode': '*530#'},
//       {'text': 'TELECEL CHECK YOUR NUMBER \n *127#', 'ussdCode': '*127#'},
//       {'text': 'CHECK IF SIM IS REGISTERED \n *400#', 'ussdCode': '*400#'},
//     ];
//
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.bottomCenter,
//             end: Alignment.topCenter,
//             colors: [Colors.red, Colors.white],
//           ),
//         ),
//         child: ListView.builder(
//           padding: const EdgeInsets.only(top: 10),
//           itemCount: buttonData.length,
//           itemBuilder: (context, index) {
//             final data = buttonData[index];
//             return _buildButton(data['text']!, data['ussdCode']!);
//           },
//         ),
//       ),
//     );
//   }
// }
