import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../chat/screens/vendor_chat_detail_screen.dart';
import '../../listings/models/bundle_listing_model.dart';
import '../../listings/repositories/listing_repository.dart';
import '../../../services/database_service.dart';
import '../widgets/listing_form_dialog.dart';
import 'updated_vendor_profile_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ListingRepository _listingRepository = ListingRepository();
  final DatabaseService _dbService = DatabaseService();
  
  // --- Multi-select chat state for vendor ---
  bool _vendorChatSelectionMode = false;
  Set<String> _selectedVendorChatIds = {};

  // --- Transactions tab filter state ---
  NetworkProvider? _selectedProvider;
  double? _minDataAmount;
  int _unreadChats = 0;
  
  // --- Tab Controller ---
  late TabController _tabController;
  
  // --- Vendor ID ---
  String get _vendorId => FirebaseAuth.instance.currentUser?.uid ?? '';

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

  // Tab builder methods
  Widget _buildListingsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('vendorId', isEqualTo: _vendorId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final listings = snapshot.data?.docs
                .map((doc) => BundleListing.fromFirestore(doc))
                .toList() ?? [];

        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No listings found', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Tap the + button to create your first listing', 
                  style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showAddListingDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Listing'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            final networkColor = _getProviderColor(listing.provider);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with network and price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: networkColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            listing.provider.toString().split('.').last,
                            style: TextStyle(
                              color: networkColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          'GHS ${listing.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Data amount and description
                    Text(
                      '${listing.dataAmount}GB',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (listing.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        listing.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Footer with stock and actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stock: ${listing.availableStock}',
                          style: TextStyle(
                            color: listing.availableStock > 0 
                                ? Colors.green[700] 
                                : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                // TODO: Implement edit functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Edit functionality coming soon')),
                                );
                              },
                              color: Colors.blue,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _deleteListing(listing),
                              color: Colors.red,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
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
  }

  Widget _buildVendorChatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('vendorId', isEqualTo: _vendorId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No chats yet', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Your chat history will appear here', 
                  style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chat = chatDoc.data() as Map<String, dynamic>;
            final buyerName = chat['buyerName'] ?? 'Buyer';
            final lastMessage = chat['lastMessage'] ?? '';
            final hasUnread = chat['hasUnread'] == true;
            final timestamp = chat['lastMessageTime'] != null 
                ? (chat['lastMessageTime'] as Timestamp).toDate() 
                : DateTime.now();
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    buyerName.isNotEmpty ? buyerName[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.blue[800]),
                  ),
                ),
                title: Text(
                  buyerName,
                  style: TextStyle(
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (hasUnread)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VendorChatDetailScreen(
                        chatId: chatDoc.id,
                        buyerId: chat['buyerId'],
                        buyerName: buyerName,
                        bundleId: chat['bundleId'] ?? '',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
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

        final transactions = snapshot.data?.docs ?? [];

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No transactions yet', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Your transaction history will appear here', 
                  style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final transaction = doc.data() as Map<String, dynamic>;
            final amount = transaction['amount'] ?? 0.0;
            final status = transaction['status']?.toString().toLowerCase() ?? 'completed';
            final timestamp = (transaction['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final buyerName = transaction['buyerName']?.toString() ?? 'Customer';
            final dataAmount = transaction['dataAmount']?.toStringAsFixed(1) ?? '0.0';
            final provider = transaction['provider']?.toString() ?? '';
            final networkProvider = provider.isNotEmpty
                ? provider.split('.').last
                : 'UNKNOWN';
            
            final statusColor = _getStatusColor(status);
            final statusText = status.toUpperCase();
            final formattedDate = '${_monthName(timestamp.month)} ${timestamp.day}, ${_formatTime(timestamp)}';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status and amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'GHS ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Transaction details
                    Row(
                      children: [
                        // Network icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getProviderColorFromString(provider).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              networkProvider[0],
                              style: TextStyle(
                                color: _getProviderColorFromString(provider),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$dataAmount GB $networkProvider',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'To: $buyerName',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Footer with date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (transaction['transactionId'] != null)
                          Text(
                            'ID: ${transaction['transactionId']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              fontFamily: 'monospace',
                            ),
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
  }

  Color _getProviderColorFromString(String provider) {
    if (provider.contains('MTN')) return Colors.yellow[700]!;
    if (provider.contains('TELECEL')) return Colors.red[700]!;
    if (provider.contains('AIRTELTIGO')) return Colors.blue[700]!;
    return Colors.grey;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAddListingDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ListingFormDialog(
        onSubmit: (formData) async {
          try {
            // Parse network provider
            final providerString = formData['provider'] as String? ?? '';
            final provider = NetworkProvider.values.firstWhere(
              (p) => p.toString() == 'NetworkProvider.$providerString',
              orElse: () => NetworkProvider.MTN,
            );

            // Parse numeric values with null safety
            final dataAmount = double.tryParse(formData['dataAmount']?.toString() ?? '') ?? 0.0;
            final price = formData['price'] is num 
                ? (formData['price'] as num).toDouble()
                : double.tryParse(formData['price']?.toString() ?? '') ?? 0.0;
            
            final estimatedDeliveryTime = int.tryParse(formData['estimatedDeliveryTime']?.toString() ?? '') ?? 5;
            final availableStock = int.tryParse(formData['availableStock']?.toString() ?? '') ?? 0;
            final minOrder = double.tryParse(formData['minOrder']?.toString() ?? '1') ?? 1.0;
            final maxOrder = (formData['maxOrder'] != null && formData['maxOrder'].toString().isNotEmpty)
                ? double.tryParse(formData['maxOrder'].toString()) ?? 0.0
                : 0.0;

            final newListing = BundleListing(
              id: '', // Will be generated by Firestore
              vendorId: _vendorId,
              provider: provider,
              dataAmount: dataAmount,
              price: price,
              description: formData['description'] as String? ?? '',
              estimatedDeliveryTime: estimatedDeliveryTime,
              availableStock: availableStock,
              status: ListingStatus.ACTIVE,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              paymentMethods: Map<String, bool>.from(formData['paymentMethods'] as Map),
              minOrder: minOrder,
              maxOrder: maxOrder,
            );

            await _listingRepository.createListing(newListing);
            if (mounted) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing created successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error creating listing: $e')),
              );
            }
          }
        },
      ),
    );

    if (result == true && mounted) {
      // Refresh listings if needed
      setState(() {});
    }
  }

  Future<void> _deleteSelectedVendorChats() async {
    final currentContext = context;
    if (_selectedVendorChatIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: currentContext,
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

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final chatId in _selectedVendorChatIds) {
          final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
          final msgSnap = await chatRef.collection('messages').get();
          for (var msg in msgSnap.docs) {
            batch.delete(msg.reference);
          }
          batch.delete(chatRef);
        }
        await batch.commit();
        if (mounted) {
          setState(() {
            _selectedVendorChatIds.clear();
            _vendorChatSelectionMode = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(content: Text('Deleted selected chat(s).')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(
              content: Text('Failed to delete chats: $e'),
              backgroundColor: Theme.of(currentContext).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteListing(BundleListing listing) async {
    final BuildContext currentContext = context;
    final confirm = await showDialog<bool>(
      context: currentContext,
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
    
    if (confirm == true && mounted) {
      try {
        await _listingRepository.deleteListing(listing.id);
        if (mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('Listing deleted successfully')),
          );
          setState(() {}); // Trigger rebuild
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Failed to delete listing: $e')),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
              final name = userData?['name'] ?? 'Vendor Dashboard';
              final isVerified = userData?['verificationStatus'] ?? false;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name),
                  if (isVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, color: Colors.blue, size: 20),
                  ],
                ],
              );
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Listings',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Row(
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
                    if (_unreadChats > 0) ...[
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
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
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(
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
            ],
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
                switch (value) {
                  case 'profile':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UpdatedVendorProfileScreen(vendorId: _vendorId),
                      ),
                    );
                    break;
                  case 'settings':
                    // TODO: Implement settings
                    break;
                }
              },
              itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('View Profile'),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Settings'),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildListingsTab(),
            _buildVendorChatsTab(),
            _buildTransactionsTab(),
          ],
        ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton(
                onPressed: _showAddListingDialog,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
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

