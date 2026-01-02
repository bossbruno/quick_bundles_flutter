import 'package:cloud_firestore/cloud_firestore.dart';

enum NetworkProvider { MTN, AIRTELTIGO, TELECEL }
enum ListingStatus { ACTIVE, INACTIVE, COMPLETED }

class BundleListing {
  // Helper: map Firestore string -> enum
  static ListingStatus _statusFromString(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'active':
        return ListingStatus.ACTIVE;
      case 'inactive':
        return ListingStatus.INACTIVE;
      case 'sold':
        return ListingStatus.COMPLETED;
      default:
        return ListingStatus.ACTIVE;
    }
  }

  // Helper: map enum -> Firestore string allowed by rules
  static String _statusToString(ListingStatus status) {
    switch (status) {
      case ListingStatus.ACTIVE:
        return 'active';
      case ListingStatus.INACTIVE:
        return 'inactive';
      case ListingStatus.COMPLETED:
        return 'sold';
    }
  }
  // Factory method to create BundleListing from Firestore DocumentSnapshot
  factory BundleListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BundleListing._fromMap(doc.id, data);
  }
  
  // Private constructor for internal use
  BundleListing._fromMap(String id, Map<String, dynamic> map) :
    id = id,
    vendorId = map['vendorId'] ?? '',
    provider = NetworkProvider.values.firstWhere(
      (e) => e.toString() == 'NetworkProvider.${map['provider']}',
      orElse: () => NetworkProvider.MTN,
    ),
    dataAmount = (map['dataAmount'] as num?)?.toDouble() ?? 0.0,
    price = (map['price'] as num?)?.toDouble() ?? 0.0,
    title = map['title'] ?? '${map['dataAmount']}GB ${map['provider'] ?? 'Bundle'}',
    description = map['description'] ?? '',
    estimatedDeliveryTime = map['estimatedDeliveryTime'] ?? 5,
    availableStock = map['availableStock'] ?? 0,
    status = _statusFromString(map['status']),
    createdAt = (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt = (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    paymentMethods = Map<String, bool>.from(map['paymentMethods'] ?? {}),
    minOrder = (map['minOrder'] as num?)?.toDouble() ?? 1.0,
    maxOrder = (map['maxOrder'] as num?)?.toDouble() ?? 0.0,
    network = map['network'] ?? map['provider']?.toString() ?? 'MTN',
    bundleSize = map['bundleSize'] ?? '${map['dataAmount']}GB',
    validity = map['validity'] ?? '30 days',
    discountPercentage = (map['discountPercentage'] as num?)?.toDouble() ?? 0.0;
  final String id;
  final String vendorId;
  final NetworkProvider provider;
  final double dataAmount; // in GB
  final double price;
  final String title; // Added: Required by Firestore rules
  final String description;
  final int estimatedDeliveryTime; // in minutes
  final int availableStock;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> paymentMethods; // e.g., {'momo': true, 'bank': false}
  final double minOrder;
  final double maxOrder;
  final String network; // Added: Required by Firestore rules
  final String bundleSize; // Added: Required by Firestore rules
  final String validity; // Added: Required by Firestore rules
  final double discountPercentage; // Added: Required by Firestore rules

  BundleListing({
    required this.id,
    required this.vendorId,
    required this.provider,
    required this.dataAmount,
    required this.price,
    required this.title,
    required this.description,
    required this.estimatedDeliveryTime,
    required this.availableStock,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.paymentMethods,
    required this.minOrder,
    required this.maxOrder,
    required this.network,
    required this.bundleSize,
    required this.validity,
    this.discountPercentage = 0.0,
  });

  BundleListing copyWith({
    String? id,
    String? vendorId,
    NetworkProvider? provider,
    double? dataAmount,
    double? price,
    String? title,
    String? description,
    int? estimatedDeliveryTime,
    int? availableStock,
    ListingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? paymentMethods,
    double? minOrder,
    double? maxOrder,
    String? network,
    String? bundleSize,
    String? validity,
    double? discountPercentage,
  }) {
    return BundleListing(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      provider: provider ?? this.provider,
      dataAmount: dataAmount ?? this.dataAmount,
      price: price ?? this.price,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      availableStock: availableStock ?? this.availableStock,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      minOrder: minOrder ?? this.minOrder,
      maxOrder: maxOrder ?? this.maxOrder,
      network: network ?? this.network,
      bundleSize: bundleSize ?? this.bundleSize,
      validity: validity ?? this.validity,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }

  // Factory method to create BundleListing from a map
  factory BundleListing.fromMap(String id, Map<String, dynamic> map) {
    return BundleListing._fromMap(id, map);
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'provider': provider.toString().split('.').last,
      'dataAmount': dataAmount,
      'price': price,
      'title': title,
      'description': description,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'availableStock': availableStock,
      'status': _statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'paymentMethods': paymentMethods,
      'minOrder': minOrder,
      'maxOrder': maxOrder,
      'network': network,
      'bundleSize': bundleSize,
      'validity': validity,
      'discountPercentage': discountPercentage,
    };
  }
}