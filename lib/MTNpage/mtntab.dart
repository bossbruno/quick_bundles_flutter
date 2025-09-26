import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_bundles_flutter/models/shortcode_model.dart';
import 'package:quick_bundles_flutter/widgets/shortcode_card.dart';
import 'package:quick_bundles_flutter/services/favorites_service.dart';

class MtnScreen extends StatefulWidget {
  const MtnScreen({Key? key}) : super(key: key);

  @override
  State<MtnScreen> createState() => _MtnScreenState();
}

class _MtnScreenState extends State<MtnScreen> {
  final List<Shortcode> _shortcodes = [
    Shortcode(
      id: 'mtn_balance',
      title: 'Balance Check',
      code: '*124#',
      description: 'Check your current airtime balance',
      network: NetworkType.mtn,
      category: 'Account',
      icon: Icons.account_balance_wallet,
    ),
    Shortcode(
      id: 'mtn_zone_balance',
      title: 'MTN Zone Balance',
      code: '*135*2*1#',
      description: 'Check your MTN Zone balance',
      network: NetworkType.mtn,
      category: 'Account',
      icon: Icons.location_on,
    ),
    Shortcode(
      id: 'mtn_momo',
      title: 'Mobile Money',
      code: '*170#',
      description: 'Access MTN Mobile Money services',
      network: NetworkType.mtn,
      category: 'Mobile Money',
      icon: Icons.money,
    ),
    Shortcode(
      id: 'mtn_mashup',
      title: 'Mashup/Pulse',
      code: '*567#',
      description: 'Access MTN Mashup/Pulse services',
      network: NetworkType.mtn,
      category: 'Entertainment',
      icon: Icons.music_note,
    ),
    Shortcode(
      id: 'mtn_offers',
      title: 'MTN Offers',
      code: '*550#',
      description: 'Check available MTN offers',
      network: NetworkType.mtn,
      category: 'Offers',
      icon: Icons.local_offer,
    ),
    Shortcode(
      id: 'mtn_check_number',
      title: 'Check Number',
      code: '*170#',
      description: 'Check your phone number',
      network: NetworkType.mtn,
      category: 'Account',
      icon: Icons.phone_android,
    ),
    Shortcode(
      id: 'mtn_report_fraud',
      title: 'Report Fraud',
      code: '1515',
      description: 'Report Mobile Money fraud',
      network: NetworkType.mtn,
      category: 'Support',
      icon: Icons.security,
    ),
    Shortcode(
      id: 'mtn_sim_registration',
      title: 'Check SIM Registration',
      code: '*400#',
      description: 'Check if your SIM is registered',
      network: NetworkType.mtn,
      category: 'Account',
      icon: Icons.sim_card,
    ),
    Shortcode(
      id: 'mtn_data_balance',
      title: 'Data Balance',
      code: '*156#',
      description: 'Check your remaining data bundle',
      network: NetworkType.mtn,
      category: 'Data',
      icon: Icons.data_usage,
    ),
    Shortcode(
      id: 'mtn_customer_service',
      title: 'Customer Service',
      code: '100',
      description: 'Contact MTN customer service',
      network: NetworkType.mtn,
      category: 'Support',
      icon: Icons.headset_mic,
    ),
  ];

  List<Shortcode> _filteredShortcodes = [];
  final TextEditingController _searchController = TextEditingController();

  final FavoritesService _favoritesService = FavoritesService();

  @override
  void initState() {
    super.initState();
    _loadShortcodes();
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
        title: const Text('MTN Shortcodes'),
        backgroundColor: Colors.amber,
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




//
//
// import 'package:flutter/material.dart';
// import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
//
// class MtnScreen extends StatefulWidget {
//   const MtnScreen({super.key});
//
//   @override
//   State<MtnScreen> createState() => _MtnScreenState();
// }
//
// class _MtnScreenState extends State<MtnScreen> {
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     Widget buildButton(String text, String ussdCode) {
//       return Padding(
//         padding: const EdgeInsets.fromLTRB(15, 20, 15, 1),
//         child: ElevatedButton(
//           onPressed: () {
//             FlutterPhoneDirectCaller.callNumber(ussdCode);
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.white,
//             foregroundColor: Colors.black,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//             fixedSize: const Size(350, 50),
//           ),
//           child: Text(
//             text,
//             textAlign: TextAlign.center,
//           ),
//         ),
//       );
//     }
//
//     List<String> buttonTexts = [
//       'MTN CREDIT BALANCE \n *124#',
//       'MTN MOBILE MONEY \n *170#',
//       'MTN DATA INFO \n *156#',
//       'MTN ZONE \n *135#',
//       'MTN CUSTOMER SERVICE \n 100',
//       'MTN MASHUP/PULSE \n *567#',
//       'MTN BEST OFFERS \n *550#',
//       'MTN CHECK YOUR NUMBER \n *156#',
//       'REPORT MOMO FRAUD \n 1515',
//       'CHECK IF SIM IS REGISTERED \n *400#'
//
//       // ...
//     ];
//
//     List<String> ussdCodes = [
//       '*124#',
//       '*170#',
//       '*156#',
//       '*135#',
//       '100',
//       '*567#',
//       '*550#',
//       '*170#',
//       '1515',
//       '*400#',
//
//       // ...
//     ];
//     return SizedBox(
//
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
//         child: Container(
//           decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                   begin: Alignment.bottomCenter,
//                   end: Alignment.topCenter,
//                   colors: [Colors.amber, Colors.white])
//           ),
//           child: ListView(
//             children: [
//               for (int i = 0; i < buttonTexts.length; i++)
//                 buildButton(buttonTexts[i], ussdCodes[i]),
//             ],
//           ),
//
//         ),
//       ),
//
//      );
//   }
// }