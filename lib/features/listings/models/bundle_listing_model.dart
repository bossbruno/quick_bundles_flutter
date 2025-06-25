import 'package:cloud_firestore/cloud_firestore.dart';

enum NetworkProvider { MTN, AIRTELTIGO, TELECEL }
enum ListingStatus { ACTIVE, INACTIVE, COMPLETED }

class BundleListing {
  final String id;
  final String vendorId;
  final NetworkProvider provider;
  final double dataAmount; // in GB
  final double price;
  final String description;
  final int estimatedDeliveryTime; // in minutes
  final int availableStock;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> paymentMethods; // e.g., {'momo': true, 'bank': false}
  final double minOrder;
  final double maxOrder;

  BundleListing({
    required this.id,
    required this.vendorId,
    required this.provider,
    required this.dataAmount,
    required this.price,
    required this.description,
    required this.estimatedDeliveryTime,
    required this.availableStock,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.paymentMethods,
    required this.minOrder,
    required this.maxOrder,
  });

  BundleListing copyWith({
    String? id,
    String? vendorId,
    NetworkProvider? provider,
    double? dataAmount,
    double? price,
    String? description,
    int? estimatedDeliveryTime,
    int? availableStock,
    ListingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? paymentMethods,
    double? minOrder,
    double? maxOrder,
  }) {
    return BundleListing(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      provider: provider ?? this.provider,
      dataAmount: dataAmount ?? this.dataAmount,
      price: price ?? this.price,
      description: description ?? this.description,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      availableStock: availableStock ?? this.availableStock,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      minOrder: minOrder ?? this.minOrder,
      maxOrder: maxOrder ?? this.maxOrder,
    );
  }

  factory BundleListing.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BundleListing(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      provider: NetworkProvider.values.firstWhere(
        (e) => e.toString() == 'NetworkProvider.${data['provider']}',
        orElse: () => NetworkProvider.MTN,
      ),
      dataAmount: (data['dataAmount'] ?? 0.0).toDouble(),
      price: (data['price'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      estimatedDeliveryTime: data['estimatedDeliveryTime'] ?? 30,
      availableStock: data['availableStock'] ?? 0,
      status: ListingStatus.values.firstWhere(
        (e) => e.toString() == 'ListingStatus.${data['status']}',
        orElse: () => ListingStatus.INACTIVE,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      paymentMethods: data['paymentMethods'] ?? {},
      minOrder: (data['minOrder'] ?? 0.0).toDouble(),
      maxOrder: (data['maxOrder'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'provider': provider.toString().split('.').last,
      'dataAmount': dataAmount,
      'price': price,
      'description': description,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'availableStock': availableStock,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'paymentMethods': paymentMethods,
      'minOrder': minOrder,
      'maxOrder': maxOrder,
    };
  }
}