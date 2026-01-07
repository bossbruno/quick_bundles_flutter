import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:quick_bundles_flutter/services/auth_service.dart';

enum UserType { user, vendor }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Vendor specific fields
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _ghanaCardController = TextEditingController();
  
  UserType _selectedUserType = UserType.user;
  bool _isLoading = false;
  File? _ghanaCardFrontImage;
  File? _ghanaCardBackImage;
  final _imagePicker = ImagePicker();

  Future<void> _pickGhanaCardImage({required bool isFront}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        setState(() {
          if (isFront) {
            _ghanaCardFrontImage = File(pickedFile.path);
          } else {
            _ghanaCardBackImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<String?> _uploadGhanaCardImage(String userId, File image, String side) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('ghana_cards')
          .child('${userId}_$side.jpg');

      await storageRef.putFile(image);
      return await storageRef.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading $side image: $e')),
      );
      return null;
    }
  }

  void _showVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.email, color: Colors.blue, size: 24),
            SizedBox(width: 10),
            Text('Verify Your Email'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We\'ve sent a verification email to:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To complete your registration and access all features, please verify your email address by clicking the link in the email we just sent you.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Check Your Spam/Junk Folder',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'If you don\'t see our email, please check your spam or junk folder. Sometimes our verification emails end up there by mistake.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AuthService().sendVerificationEmail();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email resent. Please check your inbox.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resending verification email: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Resend Email'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _ghanaCardController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that at least one Ghana Card photo is uploaded
    if (_ghanaCardFrontImage == null && _ghanaCardBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one Ghana Card photo (front or back)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      // First, check if email already exists
      try {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          throw AuthException('An account already exists with this email address.');
        }
      } on FirebaseAuthException catch (e) {
        if (e.code != 'invalid-email') rethrow;
      }
      
      // Create user account using AuthService
      final userCredential = await authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      // Upload Ghana Card images if present
      String? ghanaCardFrontImageUrl;
      String? ghanaCardBackImageUrl;
      
      if (_ghanaCardFrontImage != null) {
        ghanaCardFrontImageUrl = await _uploadGhanaCardImage(
          userCredential.user!.uid, 
          _ghanaCardFrontImage!, 
          'front'
        );
      }
      
      if (_ghanaCardBackImage != null) {
        ghanaCardBackImageUrl = await _uploadGhanaCardImage(
          userCredential.user!.uid, 
          _ghanaCardBackImage!, 
          'back'
        );
      }

      // Prepare user data
      final userData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': email,
        'phone': _phoneController.text.trim(),
        'userType': _selectedUserType.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
        'ghanaCardNumber': _ghanaCardController.text.trim(),
        'emailVerified': false,
        'isVerified': _selectedUserType == UserType.user,
      };

      // Add Ghana Card image URLs if uploaded
      if (ghanaCardFrontImageUrl != null) {
        userData['ghanaCardFrontImageUrl'] = ghanaCardFrontImageUrl;
      }
      if (ghanaCardBackImageUrl != null) {
        userData['ghanaCardBackImageUrl'] = ghanaCardBackImageUrl;
      }

      // Add vendor specific data if user is a vendor
      if (_selectedUserType == UserType.vendor) {
        userData.addAll({
          'businessName': _businessNameController.text.trim(),
          'businessAddress': _businessAddressController.text.trim(),
          'businessPhone': _businessPhoneController.text.trim(),
          'businessEmail': _businessEmailController.text.trim(),
          'isVerified': false, // Vendors need manual verification
        });
      }

      // Save additional user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        // Show verification dialog
        _showVerificationDialog(email);
      }
    } catch (e) {
      String errorMessage = 'An error occurred during sign up';
      if (e is FirebaseAuthException) {
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'An account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        }
      } else if (e is AuthException) {
        errorMessage = e.message;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'I am a:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<UserType>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Buyer'),
                              value: UserType.user,
                              groupValue: _selectedUserType,
                              onChanged: (value) {
                                setState(() => _selectedUserType = value!);
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<UserType>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Vendor'),
                              value: UserType.vendor,
                              groupValue: _selectedUserType,
                              onChanged: (value) {
                                setState(() => _selectedUserType = value!);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Common Fields
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              // Ghana Card for all users for verification
              const SizedBox(height: 24),
              const Text(
                'Identity Verification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For security purposes, we require all users to verify their identity with a Ghana Card.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ghanaCardController,
                decoration: const InputDecoration(
                  labelText: 'Ghana Card Number',
                  hintText: 'Enter your Ghana Card number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your Ghana Card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Ghana Card Front
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ghana Card Photo (Front)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Optional',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload a clear photo of the front of your Ghana Card',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (_ghanaCardFrontImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _ghanaCardFrontImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => _pickGhanaCardImage(isFront: true),
                        icon: const Icon(Icons.upload_file, size: 20),
                        label: Text(_ghanaCardFrontImage == null ? 'Upload Front Photo' : 'Change Front Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Ghana Card Back
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ghana Card Photo (Back)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Optional',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload a clear photo of the back of your Ghana Card',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (_ghanaCardBackImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _ghanaCardBackImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => _pickGhanaCardImage(isFront: false),
                        icon: const Icon(Icons.upload_file, size: 20),
                        label: Text(_ghanaCardBackImage == null ? 'Upload Back Photo' : 'Change Back Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'At least one photo (front or back) is required for verification',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Vendor Specific Fields
              if (_selectedUserType == UserType.vendor) ...[
                const SizedBox(height: 24),
                const Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_selectedUserType == UserType.vendor &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter your business name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _businessAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Business Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_selectedUserType == UserType.vendor &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter your business address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _businessPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Business Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (_selectedUserType == UserType.vendor &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter your business phone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _businessEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Business Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (_selectedUserType == UserType.vendor &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter your business email';
                    }
                    if (!value!.contains('@')) {
                      return 'Please enter a valid business email';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('Sign Up', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 