import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../models/bundle_listing_model.dart';
import '../../../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../chat/screens/chat_screen.dart';

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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.listing.dataAmount}GB Bundle',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'GH₵${widget.listing.price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    'per GB',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Stock', '${widget.listing.availableStock} GB', Icons.inventory_2_outlined),
                      const SizedBox(height: 24, child: VerticalDivider(color: Colors.white24)),
                      _buildStatItem('Delivery', '${widget.listing.estimatedDeliveryTime} min', Icons.timer_outlined),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Description
                  if (widget.listing.description.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.listing.description,
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Form Section
                  Text(
                    'Order Details',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Phone Number Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: TextFormField(
                      controller: _recipientController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        labelText: 'Recipient Number',
                        hintText: '0xx xxxx xxx',
                        prefixIcon: Icon(Icons.phone_android, color: AppTheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(),
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Amount (GB)',
                        hintText: '${widget.listing.minOrder} - ${widget.listing.maxOrder} GB',
                        prefixIcon: Icon(Icons.data_usage, color: AppTheme.primary),
                        suffixText: 'GB',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Payment Methods
                  Text(
                    'Payment Method',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widget.listing.paymentMethods.entries
                        .where((e) => e.value == true)
                        .map((e) => _buildPaymentChip(e.key))
                        .toList(),
                  ),

                  const SizedBox(height: 32),

                  // Total Price and Action
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              'GH₵${_calculateTotal().toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _createTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Purchase Bundle',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentChip(String method) {
    bool isSelected = _selectedPaymentMethod == method;
    return ChoiceChip(
      label: Text(
        method.toUpperCase(),
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPaymentMethod = selected ? method : '';
        });
      },
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      elevation: isSelected ? 4 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  double _calculateTotal() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return amount * widget.listing.price;
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

      // Query for an existing chat for this purchase (pending/processing)
      final chats = await FirebaseFirestore.instance
          .collection('chats')
          .where('buyerId', isEqualTo: user.uid)
          .where('vendorId', isEqualTo: widget.listing.vendorId)
          .where('bundleId', isEqualTo: widget.listing.id)
          .where('recipientNumber', isEqualTo: formattedNumber)
          .where('status', whereIn: ['pending', 'processing'])
          .limit(1)
          .get();

      String? existingChatId;
      if (chats.docs.isNotEmpty) {
        existingChatId = chats.docs.first.id;
      }

      if (mounted) {
        // Show success message and navigate to chat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bundle purchase initiated')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: existingChatId ?? '',
              vendorId: widget.listing.vendorId,
              bundleId: widget.listing.id,
              businessName: '', // Pass the business name if available
              recipientNumber: formattedNumber,
            ),
          ),
        );
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