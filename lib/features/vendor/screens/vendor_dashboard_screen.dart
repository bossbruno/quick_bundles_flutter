import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../listings/models/bundle_listing_model.dart';
import '../../listings/repositories/listing_repository.dart';
import '../../../services/database_service.dart';
import '../widgets/listing_form_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/screens/vendor_chat_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../vendor/screens/vendor_profile_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ListingRepository _listingRepository = ListingRepository();
  final DatabaseService _dbService = DatabaseService();
  String get _vendorId => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _unreadChats = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenUnreadCounts();
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
              tabBarTheme: TabBarTheme(
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
              tabs: [
                const Tab(icon: Icon(Icons.list_alt), text: 'My Listings'),
                const Tab(icon: Icon(Icons.receipt_long), text: 'Transactions'),
                Tab(
                  icon: Stack(
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      if (_unreadChats > 0)
                        Positioned(
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _unreadChats.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  text: 'Chats',
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateListingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Listings Tab
          StreamBuilder<List<BundleListing>>(
            stream: _listingRepository.getVendorListings(_vendorId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No listings yet'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final listing = snapshot.data![index];
                  return _buildListingCard(listing);
                },
              );
            },
          ),

          // Transactions Tab
          _buildVendorTransactionsTab(),

          // Chats Tab
          _buildVendorChatsTab(),
        ],
      ),
    );
  }

  Widget _buildListingCard(BundleListing listing) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(listing.vendorId)
          .get(),
      builder: (context, snapshot) {
        String businessName = '';
        String? vendorAvatarUrl;
        bool isVerified = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
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
                                    businessName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.green, size: 16),
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
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'GHS ${listing.price.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 6),
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
                  child: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditListingDialog(listing);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(listing);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(
      Map<String, dynamic> transaction, String transactionId) {
    final statusColor = {
      'pending': Colors.orange,
      'processing': Colors.blue,
      'completed': Colors.green,
      'failed': Colors.red,
    }[transaction['status']];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Transaction #${transactionId.substring(0, 8)}'),
            Text('GH₵${transaction['amount'].toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Bundle: ${transaction['bundleName']}'),
            Text('Recipient: ${transaction['recipientNumber']}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transaction['status'].toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                    'Created: ${_formatDate(transaction['timestamp'].toDate())}'),
              ],
            ),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction, transactionId),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCreateListingDialog() {
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

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing created successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to create listing: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditListingDialog(BundleListing listing) {
    showDialog(
      context: context,
      builder: (context) => ListingFormDialog(
        listing: listing,
        onSubmit: (data) async {
          try {
            await _listingRepository.updateListing(listing.id, {
              ...data,
              'updatedAt': DateTime.now(),
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update listing: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(BundleListing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _listingRepository.deleteListing(listing.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Listing deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete listing: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(
      Map<String, dynamic> transaction, String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction #${transactionId.substring(0, 8)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bundle: ${transaction['bundleName']}'),
            Text('Amount: ${transaction['dataAmount']}GB'),
            Text('Price: GH₵${transaction['amount'].toStringAsFixed(2)}'),
            Text('Recipient: ${transaction['recipientNumber']}'),
            Text('Status: ${transaction['status'].toUpperCase()}'),
            Text('Created: ${_formatDate(transaction['timestamp'].toDate())}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (transaction['status'] == 'pending')
            TextButton(
              onPressed: () async {
                try {
                  await _dbService.updateTransactionStatus(
                    transactionId,
                    'processing',
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Transaction marked as processing')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to update transaction: $e')),
                    );
                  }
                }
              },
              child: const Text('Mark as Processing'),
            ),
          if (transaction['status'] == 'processing')
            TextButton(
              onPressed: () async {
                try {
                  await _dbService.updateTransactionStatus(
                    transactionId,
                    'completed',
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Transaction marked as completed')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to update transaction: $e')),
                    );
                  }
                }
              },
              child: const Text('Mark as Completed'),
            ),
        ],
      ),
    );
  }

  Widget _buildVendorChatsTab() {
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
          return const Center(child: Text('No chats yet'));
        }
        final chats = snapshot.data!.docs;
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final data = chat.data() as Map<String, dynamic>;
            final buyerId = data['buyerId'] ?? '';
            final bundleId = data['bundleId'] ?? '';
            final status = data['status'] ?? 'pending';
            final chatId = chat.id;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(buyerId)
                  .get(),
              builder: (context, userSnap) {
                String buyerName = 'Buyer';
                if (userSnap.hasData && userSnap.data!.exists) {
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>?;
                  buyerName = userData?['name'] ?? 'Buyer';
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: chat.reference
                      .collection('messages')
                      .where('isRead', isEqualTo: false)
                      .where('senderId', isEqualTo: buyerId)
                      .snapshots(),
                  builder: (context, msgSnap) {
                    final unread = msgSnap.data?.docs.length ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(buyerName),
                      subtitle:
                          Text('Status: ${status.toString().toUpperCase()}'),
                      trailing: unread > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VendorChatDetailScreen(
                              chatId: chatId,
                              buyerId: buyerId,
                              buyerName: buyerName,
                              bundleId: bundleId,
                            ),
                          ),
                        );
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

  Widget _buildVendorTransactionsTab() {
    return StreamBuilder<QuerySnapshot>(
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
          return const Center(child: Text('No completed transactions yet'));
        }
        final transactions = snapshot.data!.docs;
        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index].data() as Map<String, dynamic>;
            final bundleName = tx['bundleName'] ?? '';
            final dataAmount = tx['dataAmount'] ?? '';
            final price = tx['amount']?.toStringAsFixed(2) ?? '';
            final recipientNumber = tx['recipientNumber'] ?? '';
            final network = tx['provider'] ?? '';
            final status = tx['status'] ?? '';
            final timestamp = tx['timestamp'] != null
                ? (tx['timestamp'] as Timestamp).toDate()
                : null;
            final timeString = timestamp != null
                ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                : '';
            final chatId = tx['chatId'];
            final buyerId = tx['userId'];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('$bundleName - $dataAmount GB'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price: GH₵$price'),
                    Text('Recipient: $recipientNumber'),
                    Text('Network: $network'),
                    Text('Status: ${status.toString().toUpperCase()}'),
                    if (timeString.isNotEmpty) Text('Date: $timeString'),
                  ],
                ),
                onTap: () {
                  if (chatId != null && buyerId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VendorChatDetailScreen(
                          chatId: chatId,
                          buyerId: buyerId,
                          buyerName:
                              '', // You can fetch/display buyer name if needed
                          bundleId: tx['bundleId'] ?? '',
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
