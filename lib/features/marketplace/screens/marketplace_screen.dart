import 'package:flutter/material.dart';
import '../../listings/models/bundle_listing_model.dart';
import '../../listings/repositories/listing_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../chat/screens/chat_screen.dart' show ChatScreen;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../vendor/screens/updated_vendor_profile_screen.dart';
import '../../auth/screens/buyer_profile_screen.dart';
import 'package:flutter/services.dart';


class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> with SingleTickerProviderStateMixin {
  bool _navigatingToChat = false;
  final ListingRepository _listingRepository = ListingRepository();
  NetworkProvider? _selectedProvider;
  double? _maxPrice;
  double? _minDataAmount;
  int? _maxDeliveryTime;
  late TabController _tabController;

  // --- Multi-select chat state ---
  bool _chatSelectionMode = false;
  Set<String> _selectedChatIds = {};

  void _toggleChatSelectionMode([bool? value]) {
    setState(() {
      _chatSelectionMode = value ?? !_chatSelectionMode;
      if (!_chatSelectionMode) _selectedChatIds.clear();
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _deleteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: const Text('Delete Chats'),
        content: Text(
              'Are you sure you want to delete ${_selectedChatIds
                  .length} selected chat(s)? This will also delete all messages inside.',
              style: TextStyle(color: Theme
                  .of(context)
                  .colorScheme
                  .onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
                style: TextButton.styleFrom(foregroundColor: Theme
                    .of(context)
                    .colorScheme
                    .primary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(
                  backgroundColor: Theme
                      .of(context)
                      .colorScheme
                      .error,
                  foregroundColor: Theme
                      .of(context)
                      .colorScheme
                      .onError,
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (final chatId in _selectedChatIds) {
          final chatRef = FirebaseFirestore.instance.collection('chats').doc(
              chatId);
          // Delete all messages in the chat
          final msgSnap = await chatRef.collection('messages').get();
          for (var msg in msgSnap.docs) {
            batch.delete(msg.reference);
          }
          batch.delete(chatRef);
        }
        await batch.commit();
        setState(() {
          _selectedChatIds.clear();
          _chatSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted selected chat(s).')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chats: $e'),
              backgroundColor: Theme
                  .of(context)
                  .colorScheme
                  .error),
        );
      }
    }
  }

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

  void _debugNavigationState() {
    debugPrint('Navigation state: _navigatingToChat = $_navigatingToChat');
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
          stream: FirebaseFirestore.instance.collection('users').doc(
              currentUser.uid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text('Marketplace');
                  }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Colors.blue, size: 18),
                  SizedBox(width: 6),
                  Text('Unknown Vendor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              );
            }
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) {
              return Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Colors.blue, size: 18),
                  SizedBox(width: 6),
                  Text('Unknown Vendor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              );
            }
            final name = data['name'] ?? '';
            final isVerified = data['verificationStatus'] ??
                data['isVerified'] ?? false;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Marketplace',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20),
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
        actions: [
          if (_tabController.index == 1 && currentUser != null)
            if (_chatSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete selected',
                onPressed: _selectedChatIds.isEmpty
                    ? null
                    : _deleteSelectedChats,
              )
            else
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Select chats',
                onPressed: () => _toggleChatSelectionMode(true),
              ),
          if (_chatSelectionMode && _tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: () => _toggleChatSelectionMode(false),
            ),
          if (currentUser == null)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              tooltip: 'Login',
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BuyerProfileScreen(),
                    ),
                  );
                } else if (value == 'logout') {
                  _signOut();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 20),
                      SizedBox(width: 8),
                      Text('My Profile'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
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
                      const Tab(
                          icon: Icon(Icons.storefront), text: 'Marketplace'),
                      // Chats Tab with badge
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .where('buyerId', isEqualTo: FirebaseAuth.instance
                            .currentUser?.uid)
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                                12),
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
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
                            .where('userId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        completedTx.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
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
            final completedTime = tx['timestamp'] != null
                ? (tx['timestamp'] as Timestamp).toDate()
                : null;
            final formattedDate = completedTime != null
                ? '${completedTime.day.toString().padLeft(2, '0')} '
                  '${_monthName(completedTime.month)} ${completedTime.year}, '
                  '${_formatTime(completedTime)}'
                : '';
            final vendorId = tx['vendorId'] ?? '';
            if (vendorId.isEmpty) {
              // Skip or show placeholder if vendorId is missing
              return const SizedBox.shrink();
            }
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(vendorId).get(),
              builder: (context, userSnap) {
                bool isVerified = false;
                String vendorName = 'Vendor';
                if (userSnap.hasData && userSnap.data!.exists) {
                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  isVerified = userData?['isVerified'] ?? userData?['verificationStatus'] ?? false;
                  vendorName = userData?['businessName'] ?? userData?['name'] ?? 'Vendor';
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
                              vendorName,
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
                            Text(
                              'GHS ${tx['amount']?.toStringAsFixed(2) ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
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
            final chatDoc = chats[index];
            final chatId = chatDoc.id;
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final vendorId = chatData['vendorId'] ?? '';
            final bundleId = chatData['bundleId'] ?? '';
            final lastMessage = chatData['lastMessage'] ?? '';
            final lastMessageTime = chatData['lastMessageTime'] != null
                ? (chatData['lastMessageTime'] as Timestamp).toDate()
                : null;
            final selected = _selectedChatIds.contains(chatId);

    return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(
                  vendorId).get(),
              builder: (context, userSnap) {
                String vendorName = 'Vendor';
                String? vendorAvatarUrl;
        bool isVerified = false;
                if (userSnap.hasData && userSnap.data!.exists) {
                  final userData = userSnap.data!.data() as Map<String,
                      dynamic>?;
                  vendorName = userData?['businessName'] ?? userData?['name'] ??
                      'Vendor';
                  vendorAvatarUrl = userData?['avatarUrl'];
                  isVerified = userData?['verificationStatus'] ??
                      userData?['isVerified'] ?? false;
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('listings').doc(
                      bundleId).get(),
                  builder: (context, bundleSnap) {
                    String bundleInfo = '';
                    Color networkColor = Colors.grey;
                    IconData networkIcon = Icons.wifi;

                    if (bundleSnap.hasData && bundleSnap.data!.exists) {
                      final bundleData = bundleSnap.data!.data() as Map<
                          String, dynamic>;
                      if (bundleData != null) {
                        final dataAmount = bundleData['dataAmount'] ?? 0;
                        final provider = bundleData['provider'] ?? '';
                        final price = bundleData['price'] ?? 0;
                        bundleInfo = '${dataAmount}GB - GHS ${price.toStringAsFixed(2)}';
                        // Color coding for provider
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
                            networkIcon = Icons.wifi;
                        }
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: selected ? Color.alphaBlend(Colors.blue.withOpacity(0.1), Theme.of(context).cardColor) : null,
                      child: ListTile(
                        leading: _chatSelectionMode
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) => _toggleChatSelection(chatId),
                              )
                            : CircleAvatar(
                                backgroundImage: vendorAvatarUrl != null
                                    ? NetworkImage(vendorAvatarUrl)
                                    : null,
                                backgroundColor: Colors.grey[200],
                                radius: 20,
                                child: vendorAvatarUrl == null
                                    ? Icon(Icons.storefront, color: networkColor, size: 20)
                                    : null,
                              ),
                        title: Row(
  crossAxisAlignment: CrossAxisAlignment.center,
            children: [
    // Status dot
    Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: () {
          final status = chatData['status'] ?? '';
          switch (status) {
            case 'pending':
              return Colors.orange;
            case 'processing':
              return Colors.blue;
            case 'data_sent':
              return Colors.green;
            case 'completed':
              return Colors.grey;
            case 'cancelled':
              return Colors.red;
            default:
              return Colors.grey;
          }
        }(),
      ),
    ),
    Expanded(
      child: Row(
                  children: [
                    Text(
            vendorName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (isVerified) ...[
            const SizedBox(width: 3),
            Icon(Icons.verified, color: Colors.blue, size: 16),
          ],
        ],
      ),
    ),
    const SizedBox(width: 8),
    ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 65),
      child: Text(
        (() {
          final gbRaw = bundleInfo.split(' - ').first.replaceAll('GB', '').trim();
          final gbInt = int.tryParse(double.tryParse(gbRaw)?.round().toString() ?? gbRaw) ?? gbRaw;
          return '$gbInt GB';
        })(),
        style: TextStyle(
          color: networkColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
      ),
    ),

                          ]
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                                Icon(networkIcon, color: networkColor, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  bundleSnap.hasData && bundleSnap.data!.exists ? (bundleSnap.data!.data() as Map<String, dynamic>)['provider'] ?? '' : '',
                                  style: TextStyle(
                                    color: networkColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                                  child: Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (lastMessageTime != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      _formatTime(lastMessageTime),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        trailing: _chatSelectionMode
                            ? null
                            : StreamBuilder<QuerySnapshot>(
                                stream: chatDoc.reference
                                    .collection('messages')
                                    .where('isRead', isEqualTo: false)
                                    .where('senderId', isEqualTo: vendorId)
                                    .snapshots(),
                                builder: (context, unreadSnap) {
                                  final unreadCount = unreadSnap.data?.docs.length ?? 0;
                                  return unreadCount > 0
                                      ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 12),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                },
                              ),
                        onTap: () {
                          if (_chatSelectionMode) {
                            _toggleChatSelection(chatId);
                            return;
                          }
                          // Defensive: check if chat still exists in the snapshot
                          final chatStillExists = chats.any((c) => c.id == chatId);
                          if (!chatStillExists) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('This chat has been deleted.')),
                                    );
                                    return;
                                  }
                          // Navigate immediately, let ChatScreen fetch bundle
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatId: chatId,
                                vendorId: vendorId,
                                bundleId: bundleId,
                                businessName: vendorName,
                                recipientNumber: chatData['recipientNumber'] ?? '',
                              ),
                            ),
                          );
                        },
                        onLongPress: !_chatSelectionMode ? () => _toggleChatSelectionMode(true) : null,
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: const Text('Filter Listings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Provider dropdown
              DropdownButtonFormField<NetworkProvider>(
                value: _selectedProvider,
                    decoration: const InputDecoration(
                        labelText: 'Network Provider'),
                items: NetworkProvider.values.map((provider) {
                  return DropdownMenuItem(
                    value: provider,
                        child: Text(provider
                            .toString()
                            .split('.')
                            .last),
                  );
                }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedProvider = value),
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
                    onChanged: (value) =>
                        setState(() => _minDataAmount = value),
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
                    onChanged: (value) =>
                        setState(() => _maxDeliveryTime = value.round()),
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
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<NetworkProvider>(
                      value: null,
                      child: Text('All Networks'),
                    ),
                    ...NetworkProvider.values.map((provider) =>
                        DropdownMenuItem(
                          value: provider,
                          child: Text(provider
                              .toString()
                              .split('.')
                              .last),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedProvider = value),
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
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<double>(
                      value: null,
                      child: Text('Any Size'),
                    ),
                    ...[0.5, 1, 2, 5, 10, 20, 50].map((size) =>
                        DropdownMenuItem(
                          value: size.toDouble(),
                          child: Text(size == size.roundToDouble() ? '${size
                              .toInt()} GB' : '$size GB'),
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
        // Featured Bundles Horizontal Section
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('listings')
              .where('featured', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('Error loading featured bundles')),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            final featuredBundles = snapshot.data!.docs.map((doc) =>
                BundleListing.fromFirestore(doc)).toList();
            return SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: featuredBundles.length,
                separatorBuilder: (context, i) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final listing = featuredBundles[i];
                  return SizedBox(
                    width: 260,
                    child: _buildFeaturedBundleCard(listing),
                  );
                },
              ),
            );
          },
        ),
        // All Bundles Grid View
        Expanded(
          child: StreamBuilder<List<BundleListing>>(
            stream: _listingRepository.getAllListings(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No bundles available'));
              }
              // Apply filters
              List<BundleListing> listings = snapshot.data!;
              if (_selectedProvider != null) {
                listings =
                    listings
                        .where((l) => l.provider == _selectedProvider)
                        .toList();
              }
              if (_minDataAmount != null) {
                listings =
                    listings
                        .where((l) => l.dataAmount >= _minDataAmount!)
                        .toList();
              }
              if (listings.isEmpty) {
                return const Center(
                    child: Text('No bundles match your filters'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final listing = listings[index];
                  return _buildGridBundleCard(listing);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Featured Card Widget ---
  Widget _buildFeaturedBundleCard(BundleListing listing) {
    Color networkColor;
    switch (listing.provider.toString().toUpperCase()) {
      case 'NETWORKPROVIDER.MTN':
        networkColor = Color(0xFFFBC02D); // Yellow
                          break;
      case 'NETWORKPROVIDER.TELECEL':
        networkColor = Color(0xFFD32F2F); // Red
                          break;
      case 'NETWORKPROVIDER.AIRTELTIGO':
        networkColor = Color(0xFF1976D2); // Blue
                          break;
                        default:
        networkColor = Colors.grey;
    }
    return Builder(
      builder: (context) =>
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            color: Colors.yellow[100],
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront, color: networkColor, size: 20),
                      const SizedBox(width: 8),
                      Icon(Icons.star, color: Colors.orange[800], size: 22),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(listing.description, maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Text('Delivery: ~${listing.estimatedDeliveryTime}min',
        style: const TextStyle(fontSize: 13)),
    const SizedBox(height: 10),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: networkColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
                                  child: const Text('Cancel',
                                      style: TextStyle(
                                          color: Colors.black)),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final number = recipientController
                                        .text.trim();
                                    if (number.length != 10) {
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                        const SnackBar(content: Text(
                                            'Please enter a valid 10-digit recipient number')),
                                      );
                                      return;
                                    }
                                    Navigator.pop(context, number);
                                  },
                                  style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.black),
                                  child: const Text('Continue',
                                      style: TextStyle(
                                          color: Colors.black)),
                                ),
                              ],
                            ),
                          );
                          if (result != null && result.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChatScreen(
                                      chatId: '',
                                      // No chatId for new purchase
                                      vendorId: listing.vendorId,
                                      bundleId: listing.id,
                                      businessName: listing.vendorId ?? '',
                                      recipientNumber: result,
                                    ),
                              ),
                              );
                            }
                          },
                          child: const Text('Buy'),
                        ),
                      ),
                    ],
                    ),
                  ],
                ),
              ),

            ),
      );
    }

    Widget _buildGridBundleCard(BundleListing listing) {
  Color networkColor;
  switch (listing.provider.toString().toUpperCase()) {
    case 'NETWORKPROVIDER.MTN':
      networkColor = Color(0xFFFBC02D); // Yellow
      break;
    case 'NETWORKPROVIDER.TELECEL':
      networkColor = Color(0xFFD32F2F); // Red
      break;
    case 'NETWORKPROVIDER.AIRTELTIGO':
      networkColor = Color(0xFF1976D2); // Blue
      break;
    default:
      networkColor = Colors.grey;
  }
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                      backgroundColor: Colors.grey[200],
                                      radius: 24,
    child: Icon(Icons.storefront, color: networkColor, size: 24),
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
  child: FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('users').doc(listing.vendorId).get(),
    builder: (context, snapshot) {
      String businessName = 'Vendor';
      bool isVerified = false;
      if (snapshot.hasData && snapshot.data!.exists) {
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        businessName = data?['businessName'] ?? data?['name'] ?? 'Vendor';
        isVerified = data?['isVerified'] == true || data?['verificationStatus'] == true;
      }
      // Network pill color and label
      Color pillColor;
      String networkLabel;
      switch (listing.provider) {
        case NetworkProvider.MTN:
          pillColor = Color(0xFFFBC02D);
          networkLabel = 'MTN';
          break;
        case NetworkProvider.TELECEL:
          pillColor = Color(0xFFD32F2F);
          networkLabel = 'Telecel';
          break;
        case NetworkProvider.AIRTELTIGO:
          pillColor = Color(0xFF1976D2);
          networkLabel = 'AirtelTigo';
          break;
        default:
          pillColor = Colors.grey;
          networkLabel = 'Unknown';
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                                                child: Text(
        businessName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                              ),
                                            ),
                                            if (isVerified) ...[
      const SizedBox(width: 2),
      Icon(Icons.verified, color: Colors.blue, size: 16),
                                            ],
                                          ],
                                        ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              networkLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    },
  ),
                                        ),
                                      ],
                                    ),
                  // Network label row (remove for now, will add pill later)
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
                      color: networkColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          '${listing.dataAmount}GB',
  style: TextStyle(
                                            fontWeight: FontWeight.bold,
    fontSize: 16,
    color: networkColor,
                                          ),
                                        ),
                                      ),
                  
                                      const SizedBox(height: 6),
                                      Text(
                                        'GHS ${listing.price.toStringAsFixed(2)}',
  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
            Text(
              listing.paymentMethods.entries
                  .where((e) => e.value == true)
                  .map((e) => e.key.toUpperCase())
                  .join(', '),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        if (listing.estimatedDeliveryTime > 0 || (listing.availableStock ?? 0) > 0)
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
                if ((listing.availableStock ?? 0) > 0) ...[
                                        const Icon(Icons.inventory_2, size: 16),
                                        const SizedBox(width: 2),
                                        Text('Stock: ${listing.availableStock}'),
                                      ],
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(
            height: 36, // Reduced height
            child: ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart, size: 16), // Add cart icon
              label: const Text('Buy Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: networkColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 0), // Allow button to be smaller
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Make touch target fit content
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
                        chatId: '',
                                            vendorId: listing.vendorId,
                        bundleId: listing.id,
                        businessName: listing.vendorId ?? '',
                                            recipientNumber: result,
                                          ),
                                        ),
                  );
                }
              },
                                  ),
                                ),
                              ),
    ]
                          ),
                        ),
                      );

//                       // Vendor name and shop icon
//                       FutureBuilder<DocumentSnapshot>(
//                         future: FirebaseFirestore.instance
//                             .collection('users')
//                             .doc(listing.vendorId)
//                             .get(),
//                         builder: (context, snapshot) {
//                           if (!snapshot.hasData) {
//                             return Row(
//                               children: [
//                                 Icon(Icons.storefront_rounded,
//                                     color: Colors.blue, size: 18),
//                                 SizedBox(width: 6),
//                                 Text('Loading vendor...', style: TextStyle(
//                                     fontSize: 13, fontWeight: FontWeight.w500)),
//                               ],
//                             );
//                           }
//                           final data = snapshot.data!.data() as Map<
//                               String,
//                               dynamic>?;
//                           final businessName = data != null &&
//                               data['businessName'] != null
//                               ? data['businessName'] as String
//                               : 'Unknown Vendor';
//                           final isVerified = data != null && (data['isVerified'] == true || data['verificationStatus'] == true);
//                           return Row(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             children: [
//                               Icon(Icons.storefront_rounded, color: networkColor, size: 18),
//                               SizedBox(width: 6),
//                               Expanded(
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       child: Row(
//                                         children: [
//                                           Text(
//   businessName,
// ),
//                                         if (isVerified) ...[
//                                           const SizedBox(width: 4),
//                                           Icon(Icons.verified, color: Colors.blue, size: 16),
//                                         ],
//                                       ],
//                                     ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           );
//                         },
//                       ),
//                       SizedBox(height: 4),
//                       Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 8, vertical: 4),
//                             decoration: BoxDecoration(
//                               color: listing.provider == NetworkProvider.MTN
//                                   ? Colors.yellow[700]
//                                   : listing.provider == NetworkProvider.TELECEL
//                                       ? Colors.red[400]
//                                       : Colors.blue[400],
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                             child: Text(
//                               listing.provider.toString().split('.').last,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 13,
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 12),
//                           Text(
//                             'Delivery: ~${listing.estimatedDeliveryTime}min',
//                             style: TextStyle(fontSize: 13),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 6),
//                       Text(
//                         listing.description,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(fontSize: 13),
//                       ),
//                       SizedBox(height: 8),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Flexible(
//                             child: Text(
//                               'GHS ${listing.price.toStringAsFixed(2)}',
//                               style: TextStyle(fontWeight: FontWeight.bold),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           Align(
//                             alignment: Alignment.centerRight,
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.blue,
//                                 foregroundColor: Colors.white,
//                                 minimumSize: const Size(40, 32),
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 10, vertical: 6),
//                                 textStyle: const TextStyle(
//                                     fontWeight: FontWeight.bold),
//                               ),
//                               onPressed: () async {
//                                 final recipientController = TextEditingController();
//                                 final result = await showDialog<String>(
//                                   context: context,
//                                   builder: (context) =>
//                                       AlertDialog(
//                                         title: const Text(
//                                             'Enter Recipient Number'),
//                                         content: TextField(
//                                           controller: recipientController,
//                                           keyboardType: TextInputType.phone,
//                                           inputFormatters: [
//                                             FilteringTextInputFormatter
//                                                 .digitsOnly,
//                                             LengthLimitingTextInputFormatter(
//                                                 10),
//                                           ],
//                                           decoration: const InputDecoration(
//                                             labelText: 'Recipient Number',
//                                             hintText: 'e.g. 024XXXXXXX',
//                                           ),
//                                         ),
//                                         actions: [
//                                           TextButton(
//                                             onPressed: () =>
//                                                 Navigator.pop(context),
//                                             child: const Text('Cancel',
//                                                 style: TextStyle(
//                                                     color: Colors.black)),
//                                           ),
//                                           ElevatedButton(
//                                             onPressed: () {
//                                               final number = recipientController
//                                                   .text.trim();
//                                               if (number.length != 10) {
//                                                 ScaffoldMessenger
//                                                     .of(context)
//                                                     .showSnackBar(
//                                                   const SnackBar(content: Text(
//                                                       'Please enter a valid 10-digit recipient number')),
//                                                 );
//                                                 return;
//                                               }
//                                               Navigator.pop(context, number);
//                                             },
//                                             style: ElevatedButton.styleFrom(
//                                                 foregroundColor: Colors.black),
//                                             child: const Text('Continue',
//                                                 style: TextStyle(
//                                                     color: Colors.black)),
//                                           ),
//                                         ],
//                                       ),
//                                 );
//                                 if (result != null && result.isNotEmpty) {
//                                   Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                       builder: (context) =>
//                                           ChatScreen(
//                                             chatId: '',
//                                             // No chatId for new purchase
//                                             vendorId: listing.vendorId,
//                                             bundleId: listing.id,
//                                             businessName: listing.vendorId ??
//                                                 '',
//                                             recipientNumber: result,
//                                           ),
//                                     ),
//                                   );
//                                 }
//                               },
//                               child: const Text('Buy'),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//       );
    }

    Future<int> _getTotalUnreadCount(
        List<QueryDocumentSnapshot> chatDocs) async {
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

