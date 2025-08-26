import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../listings/models/bundle_listing_model.dart';
import '../../listings/repositories/listing_repository.dart';
import '../../../services/database_service.dart';
import '../widgets/listing_form_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/screens/vendor_chat_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'updated_vendor_profile_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen>
    with SingleTickerProviderStateMixin {
  // --- Multi-select chat state for vendor ---
  bool _vendorChatSelectionMode = false;
  Set<String> _selectedVendorChatIds = {};

  // --- Transactions tab filter state ---
  NetworkProvider? _selectedProvider;
  double? _minDataAmount;

  // --- Vendor ID ---
  String get _vendorId => FirebaseAuth.instance.currentUser?.uid ?? '';

  final ListingRepository _listingRepository = ListingRepository();
  final DatabaseService _dbService = DatabaseService();
  int _unreadChats = 0;
  late TabController _tabController;

  void _toggleVendorChatSelectionMode([bool? value]) {
    setState(() {
      _vendorChatSelectionMode = value ?? !_vendorChatSelectionMode;
      if (!_vendorChatSelectionMode) _selectedVendorChatIds.clear();
    });
  }

  void _toggleVendorChatSelection(String chatId) {
    setState(() {
      if (_selectedVendorChatIds.contains(chatId)) {
        _selectedVendorChatIds.remove(chatId);
      } else {
        _selectedVendorChatIds.add(chatId);
      }
    });
  }

  Future<void> _deleteSelectedVendorChats() async {
    if (_selectedVendorChatIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chats'),
        content: Text(
          'Are you sure you want to delete ${_selectedVendorChatIds.length} selected chat(s)? This will also delete all messages inside.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (final chatId in _selectedVendorChatIds) {
          final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
          final msgSnap = await chatRef.collection('messages').get();
          for (var msg in msgSnap.docs) {
            batch.delete(msg.reference);
          }
          batch.delete(chatRef);
        }
        await batch.commit();
        setState(() {
          _selectedVendorChatIds.clear();
          _vendorChatSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted selected chat(s).')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chats: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenUnreadCounts();
    _updateExistingChatsWithBuyerName();
  }

  Future<void> _updateExistingChatsWithBuyerName() async {
    try {
      final chats = await FirebaseFirestore.instance
          .collection('chats')
          .where('vendorId', isEqualTo: _vendorId)
          .get();
      
      for (var chatDoc in chats.docs) {
        final data = chatDoc.data() as Map<String, dynamic>;
        if (data['buyerName'] == null || data['buyerName'] == '') {
          final buyerId = data['buyerId'];
          if (buyerId != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(buyerId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>?;
              final buyerName = userData?['name'] ?? userData?['businessName'] ?? 'Buyer';
              await chatDoc.reference.update({'buyerName': buyerName});
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating existing chats: $e');
    }
  }

  void _listenUnreadCounts() {
    FirebaseFirestore.instance
        .collection('chats')
        .where('vendorId', isEqualTo: _vendorId)
        .where('status', isNotEqualTo: 'completed')
        .snapshots()
        .listen((chatSnap) async {
      int unread = 0;
      for (var chatDoc in chatSnap.docs) {
        final buyerId = chatDoc['buyerId'];
        final messagesSnap = await chatDoc.reference
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .where('senderId', isEqualTo: buyerId)
            .get();
        unread += messagesSnap.size;
      }
      if (mounted) setState(() => _unreadChats = unread);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_vendorId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('Vendor Dashboard');
            }
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final name = userData?['name'] ?? '';
            final isVerified = userData?['verificationStatus'] ??
                userData?['isVerified'] ??
                false;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Vendor Dashboard',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(
                  isVerified ? Icons.check_circle : Icons.cancel,
                  color: isVerified ? Colors.green : Colors.red,
                  size: 22,
                ),
              ],
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Theme(
            data: Theme.of(context).copyWith(
              tabBarTheme: TabBarThemeData(
                indicator: BoxDecoration(
                  color: Color(0xFFFFB300),
                  borderRadius: BorderRadius.circular(24),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorWeight: 3.0,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: EdgeInsets.zero,
              tabs: [
                Expanded(
                  child: Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront, size: 18),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Listings',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_unreadChats > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unreadChats.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Chats',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Transactions',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          actions: [
            if (_vendorChatSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _selectedVendorChatIds.isEmpty ? null : _deleteSelectedVendorChats,
                tooltip: 'Delete Selected',
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpdatedVendorProfileScreen(vendorId: _vendorId),
                    ),
                  );
                } else if (value == 'logout') {
                  FirebaseAuth.instance.signOut();
                  // Add any additional logout logic here
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 20),
                      SizedBox(width: 8),
                      Text('Vendor Profile'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
        controller: _tabController,
          children: [
          _buildListingsTab(),
          _buildChatsTab(),
          _buildVendorTransactionsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _showAddListingDialog(),
              backgroundColor: const Color(0xFFFFB300),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildListingsTab() {
    return Column(
              children: [
                // Filter bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Network filter
                      Expanded(
                        child: DropdownButtonFormField<NetworkProvider>(
                          value: _selectedProvider,
                          decoration: const InputDecoration(
                            labelText: 'Network',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<NetworkProvider>(
                              value: null,
                              child: Text('All Networks'),
                            ),
                            ...NetworkProvider.values.map((provider) => DropdownMenuItem(
                                  value: provider,
                                  child: Text(provider.toString().split('.').last),
                                )),
                          ],
                          onChanged: (value) => setState(() => _selectedProvider = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bundle size filter
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          value: _minDataAmount,
                          decoration: const InputDecoration(
                            labelText: 'Min Size (GB)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<double>(
                              value: null,
                              child: Text('Any Size'),
                            ),
                            ...[0.5, 1, 2, 5, 10, 20, 50].map((size) => DropdownMenuItem(
                                  value: size.toDouble(),
                                  child: Text(size == size.roundToDouble() ? '${size.toInt()} GB' : '$size GB'),
                                )),
                          ],
                          onChanged: (value) => setState(() => _minDataAmount = value),
                        ),
                      ),
                      // Clear filters button
                      IconButton(
                        icon: const Icon(Icons.filter_alt_off, color: Colors.redAccent),
                        tooltip: 'Clear Filters',
                        onPressed: () {
                          setState(() {
                            _selectedProvider = null;
                            _minDataAmount = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
        // Listings list
                Expanded(
                  child: StreamBuilder<List<BundleListing>>(
                    stream: _listingRepository.getVendorListings(_vendorId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No listings found'));
                      }
              var listings = snapshot.data!;
              
                      // Apply filters
                      if (_selectedProvider != null) {
                        listings = listings.where((l) => l.provider == _selectedProvider).toList();
                      }
                      if (_minDataAmount != null) {
                        listings = listings.where((l) => l.dataAmount >= _minDataAmount!).toList();
                      }
              
                      return ListView.builder(
                        itemCount: listings.length,
                        itemBuilder: (context, index) {
                          final listing = listings[index];
    return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(listing.vendorId).get(),
                    builder: (context, userSnap) {
        String businessName = '';
        String? vendorAvatarUrl;
        bool isVerified = false;
                      if (userSnap.hasData && userSnap.data!.exists) {
                        final data = userSnap.data!.data() as Map<String, dynamic>?;
          businessName = data?['businessName'] ?? '';
          vendorAvatarUrl = data?['avatarUrl'];
          isVerified = data?['verificationStatus'] ?? data?['isVerified'] ?? false;
        }
                      
        // Color coding for provider (for button)
        Color buttonColor;
        String networkLabel;
        IconData networkIcon;
        switch (listing.provider) {
          case NetworkProvider.MTN:
            buttonColor = const Color(0xFFFFB300); // MTN yellow
            networkLabel = 'MTN';
            networkIcon = Icons.wifi;
            break;
          case NetworkProvider.AIRTELTIGO:
            buttonColor = const Color(0xFF1976D2); // AirtelTigo blue
            networkLabel = 'AirtelTigo';
            networkIcon = Icons.wifi;
            break;
          case NetworkProvider.TELECEL:
            buttonColor = const Color(0xFFD32F2F); // Telecel red
            networkLabel = 'Telecel';
            networkIcon = Icons.wifi;
            break;
          default:
            buttonColor = Colors.grey;
            networkLabel = 'Unknown';
            networkIcon = Icons.wifi;
        }
                      
        // Payment methods
        final paymentMethods = listing.paymentMethods.entries
          .where((e) => e.value == true)
          .map((e) => e.key.toUpperCase())
          .toList();

    return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UpdatedVendorProfileScreen(vendorId: listing.vendorId),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage: vendorAvatarUrl != null ? NetworkImage(vendorAvatarUrl) : null,
                        backgroundColor: Colors.grey[200],
                        radius: 24,
                        child: vendorAvatarUrl == null ? Icon(Icons.storefront, color: buttonColor, size: 24) : null,
                      ),
        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                          Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UpdatedVendorProfileScreen(vendorId: listing.vendorId),
                                      ),
                                    );
                                  },
                                  child: Text(
                                                  businessName.isNotEmpty ? businessName : 'My Business',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Icon(networkIcon, color: buttonColor, size: 18),
                              const SizedBox(width: 4),
                              Text(networkLabel, style: TextStyle(color: buttonColor, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: 90,
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
              children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: buttonColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${listing.dataAmount}GB',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                                fontSize: 16,
                              color: buttonColor,
                            ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'GHS ${listing.price.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    )
          ],
        ),
                const SizedBox(height: 8),
                Text(listing.description, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis, maxLines: 2),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.payments, size: 18),
                    const SizedBox(width: 4),
                    Text(paymentMethods.join(', '), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                if (listing.estimatedDeliveryTime > 0 || listing.availableStock > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        if (listing.estimatedDeliveryTime > 0) ...[
                          const Icon(Icons.timer, size: 16),
                          const SizedBox(width: 2),
                          Text('${listing.estimatedDeliveryTime} min delivery'),
                          const SizedBox(width: 12),
                        ],
                        if (listing.availableStock > 0) ...[
                          const Icon(Icons.inventory_2, size: 16),
                          const SizedBox(width: 2),
                          Text('Stock: ${listing.availableStock}'),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
            ),
            const PopupMenuItem(
              value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete'),
          ],
        ),
      ),
              ],
                                  onSelected: (value) => _handleListingAction(value, listing),
                                ),
          ),
        ],
      ),
                        ),
                    );
                    },
                    );
                },
                    );
            },
          ),
            ),
        ],
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('vendorId', isEqualTo: _vendorId)
                .where('status', isNotEqualTo: 'completed')
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No chats found'));
              }
              final chats = snapshot.data!.docs;
              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chatId = chatDoc.id;
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final buyerName = chatData['buyerName'] ?? 'Unknown';
            final lastMessage = chatData['lastMessage'] ?? '';
            final lastMessageTime = chatData['lastMessageTime'] != null
                ? (chatData['lastMessageTime'] as Timestamp).toDate()
                : null;
            final bundleId = chatData['bundleId'] ?? '';
            final status = chatData['status'] ?? 'pending';
                  final selected = _selectedVendorChatIds.contains(chatId);

            // Status color map
            final Map<String, Color> statusColors = {
              'pending': Colors.orange,
              'processing': Colors.blue,
              'data_sent': Colors.green,
              'completed': Colors.grey, // completed can be grey or another color if you want
              'cancelled': Colors.red,
            };
            final statusColor = statusColors[status] ?? Colors.grey;

                  return FutureBuilder<DocumentSnapshot>(
              future: bundleId.isNotEmpty
                  ? FirebaseFirestore.instance.collection('listings').doc(bundleId).get()
                  : Future.value(null),
              builder: (context, bundleSnap) {
                String bundleInfo = '';
                Color networkColor = Colors.grey;
                IconData networkIcon = Icons.wifi;
                if (bundleSnap.hasData && bundleSnap.data != null && bundleSnap.data!.exists) {
                  final bundleData = bundleSnap.data!.data() as Map<String, dynamic>?;
                  if (bundleData != null) {
                    final dataAmount = bundleData['dataAmount'] ?? 0;
                    final provider = bundleData['provider'] ?? '';
                    final price = bundleData['price'] ?? 0;
                    bundleInfo = '${dataAmount}GB - GHS ${price.toStringAsFixed(2)}';
                    switch (provider) {
                      case 'MTN':
                        networkColor = const Color(0xFFFFB300);
                        networkIcon = Icons.wifi;
                        break;
                      case 'AIRTELTIGO':
                        networkColor = const Color(0xFF1976D2);
                        networkIcon = Icons.wifi;
                        break;
                      case 'TELECEL':
                        networkColor = const Color(0xFFD32F2F);
                        networkIcon = Icons.wifi;
                        break;
                      default:
                        networkColor = Colors.grey;
                    }
                  }
                      }
                      return StreamBuilder<QuerySnapshot>(
                  stream: chatDoc.reference
                            .collection('messages')
                            .where('isRead', isEqualTo: false)
                      .where('senderId', isEqualTo: chatData['buyerId'])
                            .snapshots(),
                  builder: (context, unreadSnap) {
                    final unreadCount = unreadSnap.data?.docs.length ?? 0;
                          return ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status dot
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          _vendorChatSelectionMode
                              ? Checkbox(
                                  value: selected,
                                  onChanged: (value) => _toggleVendorChatSelection(chatId),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.blue,
                                      child: Text(
                                    buyerName.isNotEmpty ? buyerName[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                ),
                        ],
                      ),
                      title: Text(
                        buyerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (bundleInfo.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(networkIcon, color: networkColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  bundleInfo,
                                  style: TextStyle(
                                    color: networkColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
          ),
        ),
      ],
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (lastMessageTime != null)
                            Text(
                              _formatTime(lastMessageTime),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                      trailing: _vendorChatSelectionMode
                        ? null
                          : (unreadCount > 0
                            ? Container(
                                  padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              )
                              : const SizedBox.shrink()),
                      onTap: () {
                        if (_vendorChatSelectionMode) {
                          _toggleVendorChatSelection(chatId);
                        } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VendorChatDetailScreen(
                              chatId: chatId,
                                buyerId: chatData['buyerId'] ?? '',
                              buyerName: buyerName,
                                bundleId: chatData['bundleId'] ?? '',
                            ),
                          ),
                        );
                        }
                      },
                      onLongPress: !_vendorChatSelectionMode ? () => _toggleVendorChatSelectionMode(true) : null,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVendorTransactionsTab() {
    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Network filter
              Expanded(
                child: DropdownButtonFormField<NetworkProvider>(
                  value: _selectedProvider,
                  decoration: const InputDecoration(
                    labelText: 'Network',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<NetworkProvider>(
                      value: null,
                      child: Text('All Networks'),
                    ),
                    ...NetworkProvider.values.map((provider) => DropdownMenuItem(
                          value: provider,
                          child: Text(provider.toString().split('.').last),
                        )),
                  ],
                  onChanged: (value) => setState(() => _selectedProvider = value),
                ),
              ),
              const SizedBox(width: 12),
              // Bundle size filter
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: _minDataAmount,
                  decoration: const InputDecoration(
                    labelText: 'Min Size (GB)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<double>(
                      value: null,
                      child: Text('Any Size'),
                    ),
                    ...[0.5, 1, 2, 5, 10, 20, 50].map((size) => DropdownMenuItem(
                          value: size.toDouble(),
                          child: Text(size == size.roundToDouble() ? '${size.toInt()} GB' : '$size GB'),
                        )),
                  ],
                  onChanged: (value) => setState(() => _minDataAmount = value),
                ),
              ),
              // Clear filters button
              IconButton(
                icon: const Icon(Icons.filter_alt_off, color: Colors.redAccent),
                tooltip: 'Clear Filters',
                onPressed: () {
                  setState(() {
                    _selectedProvider = null;
                    _minDataAmount = null;
                  });
                },
              ),
            ],
          ),
        ),
        // Transactions list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('vendorId', isEqualTo: _vendorId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No transactions found'));
              }
              
              var filtered = snapshot.data!.docs.where((doc) {
                final tx = doc.data() as Map<String, dynamic>;
                final provider = tx['provider'] as String?;
                final dataAmount = tx['dataAmount'] as double?;
                
                final providerMatch = _selectedProvider == null || provider == _selectedProvider.toString();
                final sizeMatch = _minDataAmount == null || (dataAmount != null && dataAmount >= _minDataAmount!);
                
                return providerMatch && sizeMatch;
              }).toList();
              
              if (filtered.isEmpty) {
                return const Center(child: Text('No transactions match your filters'));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final tx = doc.data() as Map<String, dynamic>;
                  final timestamp = tx['timestamp'] != null ? (tx['timestamp'] as Timestamp).toDate() : null;
                  final formattedDate = timestamp != null
                      ? '${timestamp.day.toString().padLeft(2, '0')} '
                        '${_monthName(timestamp.month)} ${timestamp.year}, '
                        '${_formatTime(timestamp)}'
                      : '';
                  final isVerified = true; // Vendors are always verified here
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront, size: 20, color: Colors.orange),
                              const SizedBox(width: 6),
                              Text(
                                tx['buyerName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified, color: Colors.blue, size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on, size: 18, color: Colors.teal),
                              const SizedBox(width: 4),
                              Text('GHS ${tx['amount']?.toStringAsFixed(2) ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(width: 16),
                              if (tx['dataAmount'] != null && tx['dataAmount'].toString().isNotEmpty) ...[
                                const Icon(Icons.swap_vert, size: 18, color: Colors.deepPurple),
                                const SizedBox(width: 4),
                                Text('${tx['dataAmount']} GB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(width: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.phone_android, size: 18, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Text('Recipient: ${tx['recipientNumber'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.deepPurple),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddListingDialog() {
    showDialog(
      context: context,
      builder: (context) => ListingFormDialog(
        onSubmit: (data) async {
          try {
            await _listingRepository.createListing(
              BundleListing(
                id: '', // Will be set by Firestore
                vendorId: _vendorId,
                provider: NetworkProvider.values.firstWhere(
                  (e) => e.toString() == 'NetworkProvider.${data['provider']}',
                ),
                dataAmount: data['dataAmount'],
                price: data['price'],
                description: data['description'],
                estimatedDeliveryTime: data['estimatedDeliveryTime'],
                availableStock: data['availableStock'],
                status: ListingStatus.ACTIVE,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                paymentMethods: data['paymentMethods'],
                minOrder: data['minOrder'],
                maxOrder: data['maxOrder'],
              ),
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Listing created successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create listing: $e')),
            );
          }
        },
      ),
    );
  }

  void _handleListingAction(String action, BundleListing listing) {
    switch (action) {
      case 'edit':
        // TODO: Implement edit functionality
        break;
      case 'delete':
        _deleteListing(listing);
        break;
    }
  }

  Future<void> _deleteListing(BundleListing listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _listingRepository.deleteListing(listing.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete listing: $e')),
        );
      }
    }
  }

  Color _getProviderColor(NetworkProvider provider) {
    switch (provider) {
      case NetworkProvider.MTN:
        return Colors.yellow;
      case NetworkProvider.TELECEL:
        return Colors.red;
      case NetworkProvider.AIRTELTIGO:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
}
