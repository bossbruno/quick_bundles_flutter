import 'package:flutter/material.dart';
import '../models/bundle_listing_model.dart';
import '../../../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListingDetailsScreen extends StatefulWidget {
  final BundleListing listing;

  const ListingDetailsScreen({Key? key, required this.listing}) : super(key: key);

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  String _selectedPaymentMethod = '';
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.listing.dataAmount}GB Bundle'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GH₵${widget.listing.price.toStringAsFixed(2)} per GB',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(widget.listing.description),
                      const SizedBox(height: 16),
                      Text(
                        'Available Stock: ${widget.listing.availableStock}GB',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Delivery Time: ${widget.listing.estimatedDeliveryTime} minutes',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _recipientController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Recipient Phone Number',
                          hintText: 'Enter the number to receive the bundle',
                          prefixText: '+233 ',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (GB)',
                          hintText: 'Enter amount between ${widget.listing.minOrder} and ${widget.listing.maxOrder} GB',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Payment Method',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: widget.listing.paymentMethods.entries
                            .where((e) => e.value == true)
                            .map((e) => ChoiceChip(
                                  label: Text(e.key.toUpperCase()),
                                  selected: _selectedPaymentMethod == e.key,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedPaymentMethod = selected ? e.key : '';
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      if (_amountController.text.isNotEmpty)
                        Text(
                          'Total Price: GH₵${(double.tryParse(_amountController.text) ?? 0 * widget.listing.price).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _createTransaction,
                          child: _isProcessing
                              ? const CircularProgressIndicator()
                              : const Text('Purchase Bundle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePhoneNumber(String number) {
    // Remove any spaces or special characters
    final cleanNumber = number.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid Ghana number
    if (cleanNumber.length != 9 && cleanNumber.length != 10) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }

  void _createTransaction() async {
    // Validate input
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < widget.listing.minOrder || amount > widget.listing.maxOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid amount between ${widget.listing.minOrder} and ${widget.listing.maxOrder} GB')),
      );
      return;
    }

    if (_selectedPaymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    // Validate phone number
    final phoneValidation = _validatePhoneNumber(_recipientController.text);
    if (phoneValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneValidation)),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Format the phone number
      final cleanNumber = _recipientController.text.replaceAll(RegExp(r'[^\d]'), '');
      final formattedNumber = cleanNumber.length == 9 ? '0$cleanNumber' : cleanNumber;

      // Create new transaction
      await _dbService.createTransaction(
        userId: user.uid,
        type: 'bundle_purchase',
        amount: amount * widget.listing.price,
        status: 'pending',
        bundleId: widget.listing.id,
        recipientNumber: formattedNumber,
        provider: widget.listing.provider.toString().split('.').last,
      );

      if (mounted) {
        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bundle purchase initiated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to purchase bundle: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}