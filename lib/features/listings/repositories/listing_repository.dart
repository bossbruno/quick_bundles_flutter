import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bundle_listing_model.dart';
import '../../../core/services/network_service.dart';

class ListingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NetworkService _networkService = NetworkService();
  final String _collection = 'listings';

  // Map enum to Firestore string used by rules
  String _statusToString(ListingStatus status) {
    switch (status) {
      case ListingStatus.ACTIVE:
        return 'active';
      case ListingStatus.INACTIVE:
        return 'inactive';
      case ListingStatus.COMPLETED:
        return 'sold';
    }
  }

  // Cache for listings
  List<BundleListing>? _cachedListings;
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 5);

  // Get all active listings with caching
  Stream<List<BundleListing>> getActiveListings() {
    return _firestore
        .collection(_collection)
        .where('status', whereIn: ['active', 'ACTIVE'])
        .orderBy('price')
        .snapshots()
        .map((snapshot) {
          final listings = snapshot.docs
              .map((doc) => BundleListing.fromFirestore(doc))
              .toList();
          _cachedListings = listings;
          _lastFetchTime = DateTime.now();
          return listings;
        });
  }

  // Get listings by vendor
  Stream<List<BundleListing>> getVendorListings(String vendorId) {
    return _firestore
        .collection(_collection)
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BundleListing.fromFirestore(doc))
              .toList();
        });
  }

  // Get filtered listings with caching and pagination
  Stream<List<BundleListing>> getFilteredListings({
    NetworkProvider? provider,
    double? maxPrice,
    double? minDataAmount,
    int? maxDeliveryTime,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    // Check cache first if no filters are applied
    if (provider == null && maxPrice == null && minDataAmount == null && maxDeliveryTime == null) {
      if (_cachedListings != null && _lastFetchTime != null) {
        if (DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
          return Stream.value(_cachedListings!);
        }
      }
    }

    Query query = _firestore
        .collection(_collection)
        .where('status', whereIn: ['active', 'ACTIVE'])
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    if (provider != null) {
      query = query.where('provider', isEqualTo: provider.toString().split('.').last);
    }

    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    if (minDataAmount != null) {
      query = query.where('dataAmount', isGreaterThanOrEqualTo: minDataAmount);
    }

    if (maxDeliveryTime != null) {
      query = query.where('estimatedDeliveryTime', isLessThanOrEqualTo: maxDeliveryTime);
    }

    return query.snapshots().map((snapshot) {
      final listings = snapshot.docs
          .map((doc) => BundleListing.fromFirestore(doc))
          .toList();
      
      // Update cache if no filters are applied
      if (provider == null && maxPrice == null && minDataAmount == null && maxDeliveryTime == null) {
        _cachedListings = listings;
        _lastFetchTime = DateTime.now();
      }
      
      return listings;
    });
  }

  // Create new listing with optimistic update
  Future<String> createListing(BundleListing listing) async {
    try {
      // Optimistic update
      if (_cachedListings != null) {
        _cachedListings!.add(listing);
      }

      // Convert to map - updatedAt is already set in the listing object
      final data = listing.toMap();
      
      DocumentReference doc = await _firestore.collection(_collection).add(data);
      
      // Update cache with the new ID
      if (_cachedListings != null) {
        final index = _cachedListings!.indexOf(listing);
        if (index != -1) {
          _cachedListings![index] = listing.copyWith(id: doc.id);
        }
      }

      return doc.id;
    } catch (e) {
      // Rollback optimistic update
      if (_cachedListings != null) {
        _cachedListings!.remove(listing);
      }
      throw Exception('Failed to create listing: $e');
    }
  }

  // Update listing with optimistic update
  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    try {
      // Optimistic update
      if (_cachedListings != null) {
        final index = _cachedListings!.indexWhere((l) => l.id == id);
        if (index != -1) {
          final oldListing = _cachedListings![index];
          _cachedListings![index] = oldListing.copyWith(
            price: data['price'] ?? oldListing.price,
            dataAmount: data['dataAmount'] ?? oldListing.dataAmount,
            description: data['description'] ?? oldListing.description,
            estimatedDeliveryTime: data['estimatedDeliveryTime'] ?? oldListing.estimatedDeliveryTime,
            availableStock: data['availableStock'] ?? oldListing.availableStock,
            status: data['status'] != null 
                ? ListingStatus.values.firstWhere(
                    (e) => e.toString() == 'ListingStatus.${data['status']}')
                : oldListing.status,
          );
        }
      }

      await _firestore.collection(_collection).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Rollback optimistic update
      _lastFetchTime = null; // Force cache refresh
      throw Exception('Failed to update listing: $e');
    }
  }

  // Delete listing with optimistic update
  Future<void> deleteListing(String id) async {
    try {
      // Optimistic update
      if (_cachedListings != null) {
        _cachedListings!.removeWhere((l) => l.id == id);
      }

      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      // Rollback optimistic update
      _lastFetchTime = null; // Force cache refresh
      throw Exception('Failed to delete listing: $e');
    }
  }

  // Update listing status with optimistic update
  Future<void> updateListingStatus(String id, ListingStatus status) async {
    try {
      // Optimistic update
      if (_cachedListings != null) {
        final index = _cachedListings!.indexWhere((l) => l.id == id);
        if (index != -1) {
          _cachedListings![index] = _cachedListings![index].copyWith(status: status);
        }
      }

      await _firestore.collection(_collection).doc(id).update({
        'status': _statusToString(status),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Rollback optimistic update
      _lastFetchTime = null; // Force cache refresh
      throw Exception('Failed to update listing status: $e');
    }
  }

  // Clear cache
  void clearCache() {
    _cachedListings = null;
    _lastFetchTime = null;
  }

  // Stream all listings (regardless of status)
  Stream<List<BundleListing>> getAllListings() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BundleListing.fromFirestore(doc))
            .toList());
  }
}