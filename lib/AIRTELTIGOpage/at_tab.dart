import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_bundles_flutter/models/shortcode_model.dart';
import 'package:quick_bundles_flutter/widgets/shortcode_card.dart';
import 'package:quick_bundles_flutter/services/favorites_service.dart';

class TigoScreen extends StatefulWidget {
  const TigoScreen({super.key});

  @override
  State<TigoScreen> createState() => _TigoScreenState();
}

class _TigoScreenState extends State<TigoScreen> {
  final List<Shortcode> _shortcodes = [
    Shortcode(
      id: 'at_balance',
      title: 'AirtelTigo Balance',
      code: '*124#',
      description: 'Check your current airtime balance',
      network: NetworkType.airteltigo,
      category: 'Account',
      icon: Icons.account_balance_wallet,
    ),
    Shortcode(
      id: 'at_money',
      title: 'Airtel Money',
      code: '*110#',
      description: 'Access Airtel Money services',
      network: NetworkType.airteltigo,
      category: 'Mobile Money',
      icon: Icons.money,
    ),
    Shortcode(
      id: 'at_internet',
      title: 'Internet Packages',
      code: '*111#',
      description: 'Browse and buy internet packages',
      network: NetworkType.airteltigo,
      category: 'Data',
      icon: Icons.wifi,
    ),
    Shortcode(
      id: 'at_service',
      title: 'Customer Service',
      code: '100',
      description: 'Contact AirtelTigo customer service',
      network: NetworkType.airteltigo,
      category: 'Support',
      icon: Icons.headset_mic,
    ),
    Shortcode(
      id: 'at_check_number',
      title: 'Check Number',
      code: '*703#',
      description: 'Check your phone number',
      network: NetworkType.airteltigo,
      category: 'Account',
      icon: Icons.phone_android,
    ),
    Shortcode(
      id: 'at_best_offers',
      title: 'Best Offers',
      code: '*533#',
      description: 'View AirtelTigo best offers',
      network: NetworkType.airteltigo,
      category: 'Offers',
      icon: Icons.local_offer,
    ),
    Shortcode(
      id: 'at_special_offers',
      title: 'Special Offers',
      code: '*499#',
      description: 'View special AirtelTigo offers',
      network: NetworkType.airteltigo,
      category: 'Offers',
      icon: Icons.star,
    ),
    Shortcode(
      id: 'at_bundle_balance',
      title: 'Bundle Balance',
      code: '*504#',
      description: 'Check your remaining data bundle',
      network: NetworkType.airteltigo,
      category: 'Data',
      icon: Icons.data_usage,
    ),
    Shortcode(
      id: 'at_self_service',
      title: 'Self Service',
      code: '*100#',
      description: 'Access AirtelTigo self-service menu',
      network: NetworkType.airteltigo,
      category: 'Account',
      icon: Icons.settings,
    ),
    Shortcode(
      id: 'at_sim_registration',
      title: 'Check SIM Registration',
      code: '*400#',
      description: 'Check if your SIM is registered',
      network: NetworkType.airteltigo,
      category: 'Account',
      icon: Icons.sim_card,
    ),
    // Add more AirtelTigo shortcodes as needed
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
        title: const Text('AirtelTigo Shortcodes'),
        backgroundColor: Colors.blue[700],
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ShortcodeCard(
                          shortcode: shortcode,
                          onTap: () => _dialShortcode(shortcode.code),
                          onFavoriteToggle: () => _toggleFavorite(shortcode.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
