import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/models/user_model.dart';
import '../../listings/models/bundle_listing_model.dart';
import '../../listings/repositories/listing_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class VendorProfileScreen extends StatefulWidget {
  final String vendorId;
  const VendorProfileScreen({Key? key, required this.vendorId}) : super(key: key);

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  NetworkProvider? _selectedProvider;
  final ListingRepository _listingRepository = ListingRepository();
  bool _isDeleting = false;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.vendorId).get(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          if (!userSnap.data!.exists) return const Center(child: Text('Vendor not found'));
          final user = UserModel.fromFirestore(userSnap.data!);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(radius: 32, child: Icon(Icons.storefront, size: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
                          Text(user.email, style: const TextStyle(color: Colors.grey)),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 18),
                              Text(user.rating.toStringAsFixed(1)),
                              const SizedBox(width: 12),
                              Text('Transactions: ${user.totalTransactions}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<NetworkProvider>(
                        value: _selectedProvider,
                        decoration: const InputDecoration(labelText: 'Network'),
                        items: NetworkProvider.values.map((provider) {
                          String label = provider == NetworkProvider.AIRTELTIGO ? 'AT' : provider.toString().split('.').last;
                          return DropdownMenuItem(
                            value: provider,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedProvider = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<BundleListing>>(
                  stream: _listingRepository.getVendorListings(widget.vendorId),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Error: \\${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    var bundles = snap.data!;
                    if (_selectedProvider != null) bundles = bundles.where((b) => b.provider == _selectedProvider).toList();
                    bundles.sort((a, b) => a.price.compareTo(b.price));
                    if (bundles.isEmpty) return const Center(child: Text('No bundles found'));
                    return ListView.builder(
                      itemCount: bundles.length,
                      itemBuilder: (context, i) {
                        final b = bundles[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text('${b.dataAmount}GB - GHS ${b.price.toStringAsFixed(2)}'),
                            subtitle: Text(b.description),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Stock: ${b.availableStock}'),
                                Text('Delivery: ${b.estimatedDeliveryTime}min'),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _confirmAccountDeletion,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Delete account & data', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }
} 