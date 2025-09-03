import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/models/user_model.dart';
import '../../listings/models/bundle_listing_model.dart';
import '../../listings/repositories/listing_repository.dart';
import 'edit_vendor_profile_screen.dart';

class UpdatedVendorProfileScreen extends StatefulWidget {
  final String vendorId;
  const UpdatedVendorProfileScreen({Key? key, required this.vendorId}) : super(key: key);

  @override
  _UpdatedVendorProfileScreenState createState() => _UpdatedVendorProfileScreenState();
}

class _UpdatedVendorProfileScreenState extends State<UpdatedVendorProfileScreen> with SingleTickerProviderStateMixin {
  NetworkProvider? _selectedProvider;
  final ListingRepository _listingRepository = ListingRepository();
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;
  bool _isCurrentUserVendor = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isCurrentUserVendor = _auth.currentUser?.uid == widget.vendorId;
    
    // Add listener to handle FAB visibility
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStatColumn(IconData icon, String label, String value, {Color color = Colors.blue}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Navigate to edit profile screen
  Future<void> _navigateToEditProfile() async {
    // Get the current user data from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.vendorId)
        .get();
        
    if (!userDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found')),
        );
      }
      return;
    }
    
    final userData = userDoc.data()!;
    final currentUser = UserModel.fromFirestore(userDoc);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditVendorProfileScreen(
          currentUser: currentUser,
        ),
      ),
    );

    if (result == true && mounted) {
      // Refresh the profile data
      setState(() {
        // Force a rebuild to show updated data
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  // Navigate to add listing screen
  void _navigateToAddListing() {
    // TODO: Implement navigation to add listing screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add listing functionality coming soon')),
    );
  }

  Future<void> _confirmAccountDeletion() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.uid != widget.vendorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own account.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete account & data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'This will request deletion of your account and personal data. You will be signed out immediately. Listings and personal data will be removed. Chats may be retained for buyers as allowed by policy.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: _isDeleting ? null : () async {
                        Navigator.of(ctx).pop();
                        await _performAccountDeletion();
                      },
                      child: _isDeleting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Delete'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _performAccountDeletion() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null || user.uid != widget.vendorId) return;
    setState(() => _isDeleting = true);
    try {
      final uid = user.uid;
      await FirebaseFirestore.instance.collection('deletionRequests').doc(uid).set({
        'uid': uid,
        'email': user.email,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'requested',
        'source': 'in_app_vendor',
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(uid).delete().catchError((_) {});

      await auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deletion requested. You have been signed out.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request deletion: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(widget.vendorId).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!userSnap.data!.exists) {
          return const Scaffold(body: Center(child: Text('Vendor not found')));
        }
        
        final user = UserModel.fromFirestore(userSnap.data!);
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vendor Profile'),
            actions: _isCurrentUserVendor
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _navigateToEditProfile,
                      tooltip: 'Edit Profile',
                    ),
                  ]
                : null,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3.0,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  icon: Icon(
                    Icons.info_outline,
                    color: _tabController.index == 0 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).primaryColor) 
                        : Colors.grey[600],
                  ),
                  text: 'Profile',
                ),
                Tab(
                  icon: Icon(
                    Icons.list_alt,
                    color: _tabController.index == 1 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).primaryColor) 
                        : Colors.grey[600],
                  ),
                  text: 'Listings',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Profile Tab
              _buildProfileTab(user),
              
              // Listings Tab
              _buildListingsTab(user),
            ],
          ),
          floatingActionButton: _isCurrentUserVendor && _tabController.index == 1
              ? FloatingActionButton(
                  onPressed: _navigateToAddListing,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Add New Listing',
                )
              : null,
        );
      },
    );
  }

  Widget _buildProfileTab(UserModel user) {
    return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme
                              .of(context)
                              .primaryColor
                              .withOpacity(0.1),
                          child: const Icon(
                            Icons.storefront,
                            size: 60,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        user.name,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Rating and Transactions
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn(
                                Icons.star,
                                'Rating',
                                user.rating.toStringAsFixed(1),
                                color: Colors.amber,
                              ),
                              _buildStatColumn(
                                Icons.swap_horiz,
                                'Transactions',
                                user.totalTransactions.toString(),
                              ),
                              _buildStatColumn(
                                Icons.thumb_up,
                                'Success Rate',
                                '${user.successRate?.toStringAsFixed(0) ??
                                    'N/A'}%',
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Vendor Info Section
                      const SizedBox(height: 24),
                      const Text(
                        'Vendor Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                          'Business Name', user.businessName ?? 'Not provided'),
                      _buildInfoRow('Phone', user.phone ?? 'Not provided'),
                      _buildInfoRow(
                          'Location', user.location ?? 'Not provided'),
                      _buildInfoRow('Member Since',
                          user.joinedDate?.toString().split(' ')[0] ?? 'N/A'),

                      // About Section
                      if (user.about?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        Text(
                          user.about!,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],

                      // Contact Button (visible to non-vendor users)
                      if (!_isCurrentUserVendor) ...[
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement contact vendor
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('Contact Vendor'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Delete Account Button (visible only to current vendor)
                      if (_isCurrentUserVendor) ...[
                        const SizedBox(height: 32),
                        const Divider(height: 24),
                        TextButton.icon(
                          onPressed: _isDeleting ? null : _confirmAccountDeletion,
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('Delete account & data', style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  )
  );
  }

  // Filter chips for better UX
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter by:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: NetworkProvider.values.map((provider) {
              final isSelected = _selectedProvider == provider;
              return FilterChip(
                label: Text(provider.toString().split('.').last),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedProvider = selected ? provider : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Price range filter
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Min Price',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    // TODO: Implement min price filter
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('to', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Max Price',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    // TODO: Implement max price filter
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTab(UserModel user) {
    return StreamBuilder<List<BundleListing>>(
      stream: _listingRepository.getVendorListings(widget.vendorId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var listings = snapshot.data ?? [];
        
        // Apply filters
        if (_selectedProvider != null) {
          listings = listings.where((listing) => listing.provider == _selectedProvider).toList();
        }
        
        // Sort by price (low to high)
        listings.sort((a, b) => a.price.compareTo(b.price));

        return Column(
          children: [
            _buildFilterChips(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: listings.length,
                itemBuilder: (context, index) {
                  final bundle = listings[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: ListTile(
                      title: Text(bundle.description),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${bundle.dataAmount}GB - GHS ${bundle.price}'),
                          Text(
                            'Delivery: ~${bundle.estimatedDeliveryTime} mins',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Text(
                          bundle.provider.toString().split('.').last[0],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      trailing: _isCurrentUserVendor
                          ? IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () {
                                // TODO: Implement edit listing
                              },
                            )
                          : ElevatedButton(
                              onPressed: () {
                                // TODO: Implement buy now
                              },
                              child: const Text('Buy Now'),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  // No need for duplicate methods here
}

