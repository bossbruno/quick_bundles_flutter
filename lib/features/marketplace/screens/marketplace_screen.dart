import 'package:flutter/material.dart';
import '../../listings/models/bundle_listing_model.dart';
import '../../listings/repositories/listing_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../chat/screens/chat_screen.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../vendor/screens/vendor_profile_screen.dart';
import 'package:flutter/services.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> with SingleTickerProviderStateMixin {
  final ListingRepository _listingRepository = ListingRepository();
  NetworkProvider? _selectedProvider;
  double? _maxPrice;
  double? _minDataAmount;
  int? _maxDeliveryTime;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: currentUser == null
            ? const Text('Marketplace')
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text('Marketplace');
                  }
                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  final name = userData?['name'] ?? '';
                  final isVerified = userData?['verificationStatus'] ?? userData?['isVerified'] ?? false;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Marketplace',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      if (isVerified)
                        const Icon(Icons.verified, color: Colors.blue, size: 22),
                      if (!isVerified)
                        const Icon(Icons.cancel, color: Colors.red, size: 22),
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
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.poppins(),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      const Tab(icon: Icon(Icons.storefront), text: 'Marketplace'),
                      // Chats Tab with badge
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .where('buyerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                            .snapshots(),
                        builder: (context, chatSnap) {
                          if (!chatSnap.hasData) {
                            return const Tab(
                              icon: Icon(Icons.chat_bubble_outline),
                              text: 'Chats',
                            );
                          }
                          final chatDocs = chatSnap.data!.docs;
                          return FutureBuilder<int>(
                            future: _getTotalUnreadCount(chatDocs),
                            builder: (context, unreadSnap) {
                              final unreadCount = unreadSnap.data ?? 0;
                              return Tab(
                                icon: Stack(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                text: 'Chats',
                              );
                            },
                          );
                        },
                      ),
                      // Transactions Tab with badge
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('transactions')
                            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                            .where('status', isEqualTo: 'completed')
                            .snapshots(),
                        builder: (context, txSnap) {
                          int completedTx = txSnap.data?.docs.length ?? 0;
                          return Tab(
                            icon: Stack(
                              children: [
                                const Icon(Icons.receipt_long),
                                if (completedTx > 0)
                                  Positioned(
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        completedTx.toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            text: 'Transactions',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (currentUser == null)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              tooltip: 'Login',
            )
          else
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: 'Logout',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarketplaceTab(currentUser),
          _buildBuyerChatsTab(currentUser),
          _buildBuyerTransactionsTab(currentUser),
        ],
      ),
    );
  }

  Widget _buildBuyerChatsTab(User? currentUser) {
    if (currentUser == null) return const Center(child: Text('Not logged in'));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('buyerId', isEqualTo: currentUser.uid)
          .where('status', isNotEqualTo: 'completed')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No chats yet'));
        }
        final chats = snapshot.data!.docs;
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final data = chat.data() as Map<String, dynamic>;
            final vendorId = data['vendorId'] ?? '';
            final bundleId = data['bundleId'] ?? '';
            final status = data['status'] ?? 'pending';
            final chatId = chat.id;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(vendorId).get(),
              builder: (context, userSnap) {
                String vendorName = 'Vendor';
                if (userSnap.hasData && userSnap.data!.exists) {
                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  vendorName = userData?['businessName'] ?? userData?['name'] ?? 'Vendor';
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: chat.reference
                      .collection('messages')
                      .where('isRead', isEqualTo: false)
                      .where('senderId', isEqualTo: vendorId)
                      .snapshots(),
                  builder: (context, msgSnap) {
                    final unread = msgSnap.data?.docs.length ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(vendorName),
                      subtitle: Text('Status: \\${status.toString().toUpperCase()}'),
                      trailing: unread > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                      onTap: () async {
                        final bundleSnap = await FirebaseFirestore.instance.collection('listings').doc(bundleId).get();
                        final bundleData = bundleSnap.data() as Map<String, dynamic>?;
                        if (bundleData != null) {
                          final listing = BundleListing.fromFirestore(bundleSnap);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                listing: listing,
                                vendorId: vendorId,
                                businessName: vendorName,
                                recipientNumber: data['recipientNumber'] ?? '',
                              ),
                            ),
                          );
                        }
                      },
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

  Widget _buildBuyerTransactionsTab(User? currentUser) {
    if (currentUser == null) return const Center(child: Text('Not logged in'));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No completed transactions yet'));
        }
        final transactions = snapshot.data!.docs;
        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index].data() as Map<String, dynamic>;
            final completedTime = tx['timestamp'] != null ? (tx['timestamp'] as Timestamp).toDate() : null;
            final formattedDate = completedTime != null
                ? '${completedTime.day.toString().padLeft(2, '0')} '
                  '${_monthName(completedTime.month)} ${completedTime.year}, '
                  '${_formatTime(completedTime)}'
                : '';
            final vendorId = tx['vendorId'] ?? '';
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(vendorId).get(),
              builder: (context, userSnap) {
                bool isVerified = false;
                if (userSnap.hasData && userSnap.data!.exists) {
                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  isVerified = userData?['isVerified'] ?? userData?['verificationStatus'] ?? false;
                }
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
                              tx['vendorName'] ?? '',
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
        );
      },
    );
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

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: onDelete,
      ),
    );
  }

  Widget _buildListingCard(BundleListing listing) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(listing.vendorId).get(),
      builder: (context, snapshot) {
        String businessName = '';
        bool isVerified = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          businessName = data?['businessName'] ?? '';
          isVerified = data?['verificationStatus'] ?? data?['isVerified'] ?? false;
        }
        final paymentMethods = listing.paymentMethods.entries
            .where((e) => e.value == true && e.key != 'cash')
            .map((e) => e.key.toUpperCase())
            .toList();

        final providerStr = listing.provider.toString().toLowerCase();
        bool isAT = providerStr.contains('at') || providerStr.contains('airteltigo');
        bool isTelecel = providerStr.contains('telecel') || providerStr.contains('vodafone');
        bool isMTN = providerStr.contains('mtn');
        Color textColor = (isAT || isTelecel) ? Colors.white : Colors.black;
        String providerDisplay = isAT ? 'AT' : (isTelecel ? 'Telecel' : listing.provider.toString().split('.').last);

        Widget cardContent = ListTile(
        contentPadding: const EdgeInsets.all(16),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (businessName.isNotEmpty)
                Row(
                  children: [
                    Text(
                      businessName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isVerified ? Icons.check_circle : Icons.cancel,
                      color: isVerified ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ],
                ),
              Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
                  Text('${listing.dataAmount}GB $providerDisplay', style: TextStyle(color: textColor)),
            Text(
                      'GHS ${listing.price.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                ],
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
              Text(listing.description, style: TextStyle(color: textColor)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Text('Delivery: ~${listing.estimatedDeliveryTime}min', style: TextStyle(color: textColor)),
                  Text('Stock: ${listing.availableStock}', style: TextStyle(color: textColor)),
                ],
              ),
              if (paymentMethods.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: paymentMethods.map((method) => Chip(
                          label: Text(method, style: const TextStyle(color: Colors.black)),
                          backgroundColor: Colors.white,
                        )).toList(),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final recipientController = TextEditingController();
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Enter Recipient Number'),
                            content: TextField(
                              controller: recipientController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Recipient Number',
                                hintText: 'e.g. 024XXXXXXX',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  final number = recipientController.text.trim();
                                  if (number.length != 10) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a valid 10-digit recipient number')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context, number);
                                },
                                style: ElevatedButton.styleFrom(foregroundColor: Colors.black),
                                child: const Text('Continue', style: TextStyle(color: Colors.black)),
                              ),
                            ],
                          ),
                        );
                        if (result != null && result.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                listing: listing,
                                vendorId: listing.vendorId,
                                businessName: businessName,
                                recipientNumber: result,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Buy'),
                    ),
                  ],
                ),
              ],
            ],
          ),
          onTap: () async {
            final recipientController = TextEditingController();
            final result = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Enter Recipient Number'),
                content: TextField(
                  controller: recipientController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Recipient Number',
                    hintText: 'e.g. 024XXXXXXX',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final number = recipientController.text.trim();
                      if (number.length != 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid 10-digit recipient number')),
                        );
                        return;
                      }
                      Navigator.pop(context, number);
                    },
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.black),
                    child: const Text('Continue', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
            );
            if (result != null && result.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    listing: listing,
                    vendorId: listing.vendorId,
                    businessName: businessName,
                    recipientNumber: result,
                  ),
                ),
              ).then((_) async {
                // After navigation, start a new purchase in the chat
                // You may need to pass the amount as well if available
                // For now, you can prompt for amount or use a default
                // Example:
                // await chatScreenKey.currentState?.startNewPurchase(amount);
              });
            }
          },
        );

        Color? cardColor;
        if (isMTN) {
          cardColor = const Color(0xFFFFC107); // Deeper MTN yellow
        } else if (isTelecel) {
          cardColor = Colors.red[800]; // Deep red for Telecel
        } else if (isAT) {
          cardColor = Colors.blue[700]; // Solid blue for AT
        } else {
          cardColor = Colors.grey[200];
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: cardContent,
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Listings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Provider dropdown
              DropdownButtonFormField<NetworkProvider>(
                value: _selectedProvider,
                decoration: const InputDecoration(labelText: 'Network Provider'),
                items: NetworkProvider.values.map((provider) {
                  return DropdownMenuItem(
                    value: provider,
                    child: Text(provider.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProvider = value),
              ),

              // Max price slider
              const SizedBox(height: 16),
              const Text('Maximum Price (GH₵)'),
              Slider(
                value: _maxPrice ?? 100,
                min: 0,
                max: 100,
                divisions: 20,
                label: 'GH₵${(_maxPrice ?? 100).toStringAsFixed(2)}',
                onChanged: (value) => setState(() => _maxPrice = value),
              ),

              // Min data amount slider
              const SizedBox(height: 16),
              const Text('Minimum Data Amount (GB)'),
              Slider(
                value: _minDataAmount ?? 0,
                min: 0,
                max: 50,
                divisions: 50,
                label: '${(_minDataAmount ?? 0).toStringAsFixed(1)}GB',
                onChanged: (value) => setState(() => _minDataAmount = value),
              ),

              // Max delivery time slider
              const SizedBox(height: 16),
              const Text('Maximum Delivery Time (minutes)'),
              Slider(
                value: _maxDeliveryTime?.toDouble() ?? 60,
                min: 0,
                max: 120,
                divisions: 12,
                label: '${(_maxDeliveryTime ?? 60)}min',
                onChanged: (value) => setState(() => _maxDeliveryTime = value.round()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedProvider = null;
                _maxPrice = null;
                _minDataAmount = null;
                _maxDeliveryTime = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showListingDetails(BundleListing listing) {
    // TODO: Navigate to listing details screen
    // This will be implemented in the next step
  }

  Widget _buildMarketplaceTab(User? currentUser) {
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
        // Listings
        Expanded(
          child: StreamBuilder<List<BundleListing>>(
            stream: _listingRepository.getAllListings(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: \\${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No bundles available'));
              }
              // Apply filters
              List<BundleListing> listings = snapshot.data!;
              if (_selectedProvider != null) {
                listings = listings.where((l) => l.provider == _selectedProvider).toList();
              }
              if (_minDataAmount != null) {
                listings = listings.where((l) => l.dataAmount >= _minDataAmount!).toList();
              }
              if (listings.isEmpty) {
                return const Center(child: Text('No bundles match your filters'));
              }
              return ListView.builder(
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final listing = listings[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(listing.vendorId).get(),
                    builder: (context, userSnap) {
                      String vendorName = 'Vendor';
                      String? vendorAvatarUrl;
                      bool isVerified = false;
                      if (userSnap.hasData && userSnap.data!.exists) {
                        final userData = userSnap.data!.data() as Map<String, dynamic>?;
                        vendorName = userData?['businessName'] ?? userData?['name'] ?? 'Vendor';
                        vendorAvatarUrl = userData?['avatarUrl'];
                        isVerified = userData?['verificationStatus'] ?? userData?['isVerified'] ?? false;
                      }
                      // Color coding for Buy Now button
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
                                          builder: (context) => VendorProfileScreen(vendorId: listing.vendorId),
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
                                                      builder: (context) => VendorProfileScreen(vendorId: listing.vendorId),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  vendorName,
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
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
                                            fontSize: 18,
                                            color: buttonColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'GHS ${listing.price.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(listing.description, style: const TextStyle(fontSize: 15)),
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
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final recipientController = TextEditingController();
                                    final result = await showDialog<String>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Enter Recipient Number'),
                                        content: TextField(
                                          controller: recipientController,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: 'Recipient Number',
                                            hintText: 'e.g. 024XXXXXXX',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              final number = recipientController.text.trim();
                                              if (number.length != 10) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Please enter a valid 10-digit recipient number')),
                                                );
                                                return;
                                              }
                                              Navigator.pop(context, number);
                                            },
                                            style: ElevatedButton.styleFrom(foregroundColor: Colors.black),
                                            child: const Text('Continue', style: TextStyle(color: Colors.black)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (result != null && result.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            listing: listing,
                                            vendorId: listing.vendorId,
                                            businessName: vendorName,
                                            recipientNumber: result,
                                          ),
                                        ),
                                      ).then((_) async {
                                        // After navigation, start a new purchase in the chat
                                        // You may need to pass the amount as well if available
                                        // For now, you can prompt for amount or use a default
                                        // Example:
                                        // await chatScreenKey.currentState?.startNewPurchase(amount);
                                      });
                                    }
                                  },
                                  child: const Text('Buy Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: buttonColor,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
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

  Future<int> _getTotalUnreadCount(List<QueryDocumentSnapshot> chatDocs) async {
    int total = 0;
    for (var chatDoc in chatDocs) {
      final vendorId = chatDoc['vendorId'];
      final unreadSnap = await chatDoc.reference
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isEqualTo: vendorId)
          .get();
      total += unreadSnap.size;
    }
    return total;
  }
}