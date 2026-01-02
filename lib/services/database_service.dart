import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get usersCollection => _db.collection('users');
  CollectionReference get transactionsCollection => _db.collection('transactions');
  CollectionReference get bundlesCollection => _db.collection('bundles');

  // Create or update user document
  Future<void> createUserDocument(
    User user, {
    String? name, 
    String? phoneNumber,
    bool? emailVerified,
  }) async {
    final userData = {
      'email': user.email,
      'name': name ?? user.displayName ?? '',
      'phoneNumber': phoneNumber ?? user.phoneNumber ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'balance': 0.0,
      'totalTransactions': 0,
      'isVerified': emailVerified ?? user.emailVerified,
      'emailVerified': emailVerified ?? user.emailVerified,
      'lastLogin': FieldValue.serverTimestamp(),
      'role': 'user', // Default role
      'userType': 'user', // Default user type
    };

    // Use set with merge to avoid overwriting existing data
    await usersCollection.doc(user.uid).set(userData, SetOptions(merge: true));
  }
  
  // Check if user profile exists
  Future<bool> doesUserProfileExist(String userId) async {
    final doc = await usersCollection.doc(userId).get();
    return doc.exists;
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await usersCollection.doc(userId).update(data);
  }

  // Get user data
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return usersCollection.doc(userId).snapshots();
  }

  // Create a new transaction (including bundle purchases)
  Future<DocumentReference> createTransaction({
    required String userId,
    required String type, // 'bundle_purchase', 'wallet_topup', etc.
    required double amount,
    required String status,
    String? bundleId,
    String? recipientNumber,
    String? provider,
    double? dataAmount, // Add dataAmount parameter
  }) async {
    Map<String, dynamic> transactionData = {
      'userId': userId,
      'type': type,
      'amount': amount,
      'status': status, // 'pending', 'processing', 'completed', 'failed'
      'timestamp': Timestamp.now(),
    };

    // Add bundle-specific data if this is a bundle purchase
    if (type == 'bundle_purchase' && bundleId != null) {
      final bundleDoc = await FirebaseFirestore.instance.collection('listings').doc(bundleId).get();
      final bundleData = bundleDoc.data();
      if (bundleData == null) {
        throw Exception('Listing not found for id: $bundleId');
      }
      
      // Calculate the data amount if not provided
      final double bundleDataAmount = dataAmount ?? (bundleData['dataAmount'] as num?)?.toDouble() ?? 0.0;
      
      transactionData.addAll({
        'bundleId': bundleId,
        'bundleName': bundleData['name'] ?? 'Data Bundle',
        'recipientNumber': recipientNumber ?? '',
        'provider': provider ?? bundleData['provider']?.toString() ?? '',
        'dataAmount': bundleDataAmount,
        'validity': bundleData['validity'] ?? 30, // Default to 30 days if not specified
        'vendorId': bundleData['vendorId'] ?? '',
        'vendorName': bundleData['businessName'] ?? 
                     bundleData['vendorName'] ?? 
                     await _getVendorName(bundleData['vendorId'] ?? '') ?? 
                     'Unknown Vendor',
        'buyerId': userId,
        'buyerName': await _getBuyerName(userId) ?? 'Unknown Buyer',
      });
    }

    final transaction = await transactionsCollection.add(transactionData);
    // Update user's total transactions
    await usersCollection.doc(userId).update({
      'totalTransactions': FieldValue.increment(1),
    });
    return transaction;
  }

  // Helper to fetch vendor's business name
  Future<String> _getVendorName(String vendorId) async {
    if (vendorId.isEmpty) return '';
    final vendorDoc = await usersCollection.doc(vendorId).get();
    if (vendorDoc.exists) {
      final vendorData = vendorDoc.data() as Map<String, dynamic>?;
      return vendorData?['businessName'] ?? vendorData?['name'] ?? '';
    }
    return '';
  }

  // Helper to fetch buyer's name
  Future<String> _getBuyerName(String buyerId) async {
    if (buyerId.isEmpty) return '';
    final buyerDoc = await usersCollection.doc(buyerId).get();
    if (buyerDoc.exists) {
      final buyerData = buyerDoc.data() as Map<String, dynamic>?;
      return buyerData?['name'] ?? buyerData?['displayName'] ?? '';
    }
    return '';
  }

  // Update transaction status
  Future<void> updateTransactionStatus(String transactionId, String status) async {
    await transactionsCollection.doc(transactionId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  // Get user transactions (can filter by type)
  Stream<QuerySnapshot> getUserTransactions(String userId, {String? type}) {
    Query query = transactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    
    return query.snapshots();
  }

  // Create or update bundle
  Future<DocumentReference> createBundle({
    required String provider,
    required String name,
    required double price,
    required int dataAmount,
    required int validity,
    required bool isAvailable,
  }) async {
    return await bundlesCollection.add({
      'provider': provider,
      'name': name,
      'price': price,
      'dataAmount': dataAmount,
      'validity': validity,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  // Get available bundles by provider
  Stream<QuerySnapshot> getBundlesByProvider(String provider) {
    return bundlesCollection
        .where('provider', isEqualTo: provider)
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }

  // Update user balance
  Future<void> updateUserBalance(String userId, double amount) async {
    await usersCollection.doc(userId).update({
      'balance': FieldValue.increment(amount),
    });
  }

  // Get user balance
  Future<double> getUserBalance(String userId) async {
    final doc = await usersCollection.doc(userId).get();
    return (doc.data() as Map<String, dynamic>)['balance'] ?? 0.0;
  }
} 