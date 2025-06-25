import 'package:flutter/material.dart';
import '../../listings/models/bundle_listing_model.dart';

class ListingFormDialog extends StatefulWidget {
  final BundleListing? listing;
  final Function(Map<String, dynamic>) onSubmit;

  const ListingFormDialog({
    Key? key,
    this.listing,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ListingFormDialog> createState() => _ListingFormDialogState();
}

class _ListingFormDialogState extends State<ListingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late NetworkProvider _selectedProvider;
  final _dataAmountController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deliveryTimeController = TextEditingController();
  final _stockController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxOrderController = TextEditingController();
  final Map<String, bool> _paymentMethods = {
    'momo': false,
    'bank': false,
  };

  @override
  void initState() {
    super.initState();
    if (widget.listing != null) {
      // Populate form with existing listing data
      _selectedProvider = widget.listing!.provider;
      _dataAmountController.text = widget.listing!.dataAmount.toString();
      _priceController.text = widget.listing!.price.toString();
      _descriptionController.text = widget.listing!.description;
      _deliveryTimeController.text = widget.listing!.estimatedDeliveryTime.toString();
      _stockController.text = widget.listing!.availableStock.toString();
      _minOrderController.text = widget.listing!.minOrder.toString();
      _maxOrderController.text = widget.listing!.maxOrder.toString();
      _paymentMethods.addAll(widget.listing!.paymentMethods.map(
        (key, value) => MapEntry(key, value as bool),
      ));
    } else {
      _selectedProvider = NetworkProvider.MTN;
    }
  }

  @override
  void dispose() {
    _dataAmountController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _deliveryTimeController.dispose();
    _stockController.dispose();
    _minOrderController.dispose();
    _maxOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.listing == null ? 'Create Listing' : 'Edit Listing'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider dropdown
              DropdownButtonFormField<NetworkProvider>(
                value: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: 'Network Provider',
                  border: OutlineInputBorder(),
                ),
                items: NetworkProvider.values.map((provider) {
                  return DropdownMenuItem(
                    value: provider,
                    child: Text(provider.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedProvider = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Data amount field
              TextFormField(
                controller: _dataAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Data Amount (GB)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter data amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price field
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price per GB (GH₵)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Delivery time field
              TextFormField(
                controller: _deliveryTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Delivery Time (minutes)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter delivery time';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Stock field
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Available Stock (GB)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter available stock';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Min and max order fields
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Order (GB)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Order (GB)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment methods
              const Text('Payment Methods',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _paymentMethods.entries
                    .where((entry) => entry.key != 'cash')
                    .map((entry) {
                  return FilterChip(
                    label: Text(entry.key.toUpperCase()),
                    selected: entry.value,
                    onSelected: (selected) {
                      setState(() {
                        _paymentMethods[entry.key] = selected;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submitForm,
          child: Text(widget.listing == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    // Ensure at least one payment method is selected
    if (!_paymentMethods.values.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one payment method')),
      );
      return;
    }

    final data = {
      'provider': _selectedProvider.toString().split('.').last,
      'dataAmount': double.parse(_dataAmountController.text),
      'price': double.parse(_priceController.text),
      'description': _descriptionController.text,
      'estimatedDeliveryTime': int.parse(_deliveryTimeController.text),
      'availableStock': int.parse(_stockController.text),
      'minOrder': double.parse(_minOrderController.text),
      'maxOrder': double.parse(_maxOrderController.text),
      'paymentMethods': _paymentMethods,
      'status': ListingStatus.ACTIVE.toString().split('.').last,
    };

    widget.onSubmit(data);
    Navigator.pop(context);
  }
}