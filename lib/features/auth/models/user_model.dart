import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String phoneNumber;
  final bool isVendor;
  final double rating;
  final int totalTransactions;
  final DateTime? joinedDate;
  final DateTime createdAt;
  final DateTime lastActive;
  final String? businessName;
  final String? location;
  final String? about;
  final double? successRate;
  final String? phone;
  final String? photoUrl;
  final String? ghanaCardUrl;
  final String? businessHours;
  final List<String>? serviceAreas;
  final Map<String, bool>? paymentMethods;
  final String id;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.phoneNumber = '',
    this.isVendor = false,
    this.rating = 0.0,
    this.totalTransactions = 0,
    this.joinedDate,
    required this.createdAt,
    required this.lastActive,
    this.businessName,
    this.location,
    this.about,
    this.successRate,
    this.phone,
    this.photoUrl,
    this.ghanaCardUrl,
    this.businessHours,
    this.serviceAreas,
    this.paymentMethods,
    this.id = '',
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? data['phone'] ?? '',
      isVendor: data['isVendor'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalTransactions: data['totalTransactions'] ?? 0,
      joinedDate: data['joinedDate'] != null ? (data['joinedDate'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      lastActive: data['lastActive'] != null ? (data['lastActive'] as Timestamp).toDate() : DateTime.now(),
      businessName: data['businessName'],
      location: data['location'],
      about: data['about'],
      successRate: data['successRate']?.toDouble(),
      phone: data['phone'] ?? data['phoneNumber'],
      photoUrl: data['photoUrl'],
      ghanaCardUrl: data['ghanaCardUrl'],
      businessHours: data['businessHours'],
      serviceAreas: data['serviceAreas'] != null ? List<String>.from(data['serviceAreas']) : null,
      paymentMethods: data['paymentMethods'] != null ? Map<String, bool>.from(data['paymentMethods']) : null,
      id: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'phone': phone,
      'isVendor': isVendor,
      'rating': rating,
      'totalTransactions': totalTransactions,
      'createdAt': createdAt,
      'lastActive': lastActive,
      'joinedDate': joinedDate,
      'businessName': businessName,
      'location': location,
      'about': about,
      'successRate': successRate,
      'ghanaCardUrl': ghanaCardUrl,
    }..removeWhere((key, value) => value == null);
  }
}