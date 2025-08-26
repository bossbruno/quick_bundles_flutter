import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../services/auth_service.dart';

class EditVendorProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const EditVendorProfileScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  _EditVendorProfileScreenState createState() => _EditVendorProfileScreenState();
}

class _EditVendorProfileScreenState extends State<EditVendorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _businessHoursController;
  late TextEditingController _serviceAreasController;
  
  Map<String, bool> _paymentMethods = {
    'momo': false,
    'bank': false,
  };

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.currentUser.about ?? '');
    _phoneController = TextEditingController(text: widget.currentUser.phone ?? '');
    _emailController = TextEditingController(text: widget.currentUser.email);
    _businessHoursController = TextEditingController(text: widget.currentUser.businessHours ?? 'Mon-Fri: 9AM-5PM');
    _serviceAreasController = TextEditingController(
      text: widget.currentUser.serviceAreas?.join(', ') ?? '',
    );
    
    // Initialize payment methods
    if (widget.currentUser.paymentMethods != null) {
      _paymentMethods = Map<String, bool>.from(widget.currentUser.paymentMethods!);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _businessHoursController.dispose();
    _serviceAreasController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.updateVendorProfile(
          userId: widget.currentUser.id,
          about: _descriptionController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          businessHours: _businessHoursController.text,
          serviceAreas: _serviceAreasController.text.split(',').map((e) => e.trim()).toList(),
          paymentMethods: _paymentMethods,
        );
        
        Navigator.of(context).pop(true); // Return success
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: widget.currentUser.photoUrl != null
                          ? NetworkImage(widget.currentUser.photoUrl!)
                          : null,
                      child: widget.currentUser.photoUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Business Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Business Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a business description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Contact Information
              const Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Business Hours
              TextFormField(
                controller: _businessHoursController,
                decoration: const InputDecoration(
                  labelText: 'Business Hours',
                  hintText: 'e.g., Mon-Fri: 9AM-5PM',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
              ),
              const SizedBox(height: 16),
              
              // Service Areas
              TextFormField(
                controller: _serviceAreasController,
                decoration: const InputDecoration(
                  labelText: 'Service Areas',
                  hintText: 'e.g., Accra, Kumasi, Tamale',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              
              // Payment Methods
              const Text('Payment Methods', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._paymentMethods.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(
                    entry.key == 'momo' ? 'Mobile Money' : 'Bank Transfer',
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: entry.value,
                  onChanged: (bool? value) {
                    setState(() {
                      _paymentMethods[entry.key] = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
