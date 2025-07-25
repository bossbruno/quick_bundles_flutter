import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
            ],
          );
        },
      ),
    );
  }
} 