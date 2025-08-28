import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/provider.dart' as app_provider;
import '../models/booking.dart';
import 'package:flutter/foundation.dart';

import 'review_service.dart' as review_service;

enum ProviderStatus { active, suspended, inactive }
enum VerificationStatus { pending, approved, rejected }
enum BookingStatus { pending, accepted, inProgress, completed, cancelled, rejected }

class ServiceOffering {
  final String serviceId;
  final String title;
  final double priceFrom;
  final double priceTo;
  final int durationMin;

  ServiceOffering({
    required this.serviceId,
    required this.title,
    required this.priceFrom,
    required this.priceTo,
    required this.durationMin,
  });

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'title': title,
      'priceFrom': priceFrom,
      'priceTo': priceTo,
      'durationMin': durationMin,
    };
  }

  factory ServiceOffering.fromMap(Map<String, dynamic> map) {
    return ServiceOffering(
      serviceId: map['serviceId'] ?? '',
      title: map['title'] ?? '',
      priceFrom: (map['priceFrom'] ?? 0.0).toDouble(),
      priceTo: (map['priceTo'] ?? 0.0).toDouble(),
      durationMin: map['durationMin'] ?? 0,
    );
  }
}

class ProviderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get provider profile
  static Future<app_provider.Provider?> getProvider(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      if (doc.exists) {
        return app_provider.Provider.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting provider: $e');
      return null;
    }
  }

  // Create provider profile
  static Future<bool> createProvider({
    required String uid,
    required String email,
    required String businessName,
    required String category,
    required String description,
    String? ownerName,
    String? phone,
  }) async {
    try {
      final provider = app_provider.Provider(
        providerId: uid,
        ownerUid: uid,
        businessName: businessName,
        description: description,
        categoryId: category,
        services: [],
        images: [],
        lat: 0.0,
        lng: 0.0,
        geohash: '',
        serviceAreaKm: 10.0,
        documents: {},
        createdAt: DateTime.now(),
        keywords: [],
      );

      await _firestore.collection('providers').doc(uid).set(provider.toMap());
      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error creating provider: $e');
      return false;
    }
  }

  // Update provider profile
  static Future<bool> updateProvider({
    required String providerId,
    String? businessName,
    String? ownerName,
    String? category,
    String? description,
    String? phone,
    String? address,
    Map<String, double>? location,
    double? serviceRadius,
    List<String>? serviceAreas,
    Map<String, String>? workingHours,
    File? profileImage,
    File? businessLogo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (businessName != null) updateData['businessName'] = businessName;
      if (ownerName != null) updateData['ownerName'] = ownerName;
      if (category != null) updateData['category'] = category;
      if (description != null) updateData['description'] = description;
      if (phone != null) updateData['phone'] = phone;
      if (address != null) updateData['address'] = address;
      if (location != null) updateData['location'] = location;
      if (serviceRadius != null) updateData['serviceRadius'] = serviceRadius;
      if (serviceAreas != null) updateData['serviceAreas'] = serviceAreas;
      if (workingHours != null) updateData['workingHours'] = workingHours;

      if (profileImage != null) {
        final imageUrl = await _uploadImageStatic(providerId, 'profile', profileImage);
        updateData['profileImageUrl'] = imageUrl;
      }

      if (businessLogo != null) {
        final logoUrl = await _uploadImageStatic(providerId, 'logo', businessLogo);
        updateData['businessLogoUrl'] = logoUrl;
      }

      await _firestore.collection('providers').doc(providerId).update(updateData);
      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error updating provider: $e');
      return false;
    }
  }

  // Upload image to Firebase Storage (static version)
  static Future<String> _uploadImageStatic(String providerId, String type, File imageFile) async {
    final ref = _storage.ref().child('provider_images/$providerId/$type/${DateTime.now().millisecondsSinceEpoch}');
    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }



  // Update online status
  Future<void> updateOnlineStatus(String providerId, bool isOnline) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'isOnline': isOnline,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error updating online status: $e');
    }
  }

  // Add/Update service offering
  Future<bool> updateServices(String providerId, List<ServiceOffering> services) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'services': services.map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error updating services: $e');
      return false;
    }
  }

  // Upload verification documents
  Future<bool> uploadVerificationDocuments({
    required String providerId,
    File? businessLicense,
    File? pacraRegistration,
    List<File>? additionalDocs,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'verificationStatus': VerificationStatus.pending.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      List<String> docUrls = [];

      if (businessLicense != null) {
        final url = await _uploadDocument(providerId, 'business_license', businessLicense);
        updateData['businessLicense'] = url;
        docUrls.add(url);
      }

      if (pacraRegistration != null) {
        final url = await _uploadDocument(providerId, 'pacra_registration', pacraRegistration);
        updateData['pacraRegistration'] = url;
        docUrls.add(url);
      }

      if (additionalDocs != null) {
        for (int i = 0; i < additionalDocs.length; i++) {
          final url = await _uploadDocument(providerId, 'additional_$i', additionalDocs[i]);
          docUrls.add(url);
        }
      }

      if (docUrls.isNotEmpty) {
        updateData['verificationDocuments'] = docUrls;
      }

      await _firestore.collection('providers').doc(providerId).update(updateData);
      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error uploading verification documents: $e');
      return false;
    }
  }

  // Upload document to Firebase Storage
  Future<String> _uploadDocument(String providerId, String docType, File file) async {
    final ref = _storage.ref().child('provider_documents/$providerId/$docType/${DateTime.now().millisecondsSinceEpoch}');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Get provider bookings
  static Stream<List<Booking>> getProviderBookings(String providerId) {
    return _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Booking.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }).toList();
    });
  }

  // Get provider earnings
  static Future<Map<String, dynamic>> getProviderEarnings(String providerId) async {
    try {
      final completedBookings = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: BookingStatus.completed.name)
          .get();

      double totalEarnings = 0;
      int completedJobs = completedBookings.docs.length;
      
      Map<String, double> monthlyEarnings = {};
      
      for (final doc in completedBookings.docs) {
        final data = doc.data()! as Map<String, dynamic>;
        final price = (data['finalPrice'] ?? data['estimatedPrice'] ?? 0).toDouble();
        totalEarnings += price;

        // Calculate monthly earnings
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        if (completedAt != null) {
          final monthKey = '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}';
          monthlyEarnings[monthKey] = (monthlyEarnings[monthKey] ?? 0) + price;
        }
      }

      return {
        'totalEarnings': totalEarnings,
        'completedJobs': completedJobs,
        'monthlyEarnings': monthlyEarnings,
        'averageJobValue': completedJobs > 0 ? totalEarnings / completedJobs : 0.0,
      };
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting provider earnings: $e');
      return {
        'totalEarnings': 0.0,
        'completedJobs': 0,
        'monthlyEarnings': <String, double>{},
        'averageJobValue': 0.0,
      };
    }
  }

  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats(String providerId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      // Get all bookings for this provider
      final allBookings = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .get();

      // Get this month's bookings
      final thisMonthBookings = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      // Get pending bookings
      final pendingBookings = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: BookingStatus.pending.name)
          .get();

      int totalBookings = allBookings.docs.length;
      int thisMonthBookingsCount = thisMonthBookings.docs.length;
      int pendingBookingsCount = pendingBookings.docs.length;
      
      int completedJobs = allBookings.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == BookingStatus.completed.name)
          .length;

      return {
        'totalBookings': totalBookings,
        'thisMonthBookings': thisMonthBookingsCount,
        'pendingBookings': pendingBookingsCount,
        'completedJobs': completedJobs,
      };
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting dashboard stats: $e');
      return {
        'totalBookings': 0,
        'thisMonthBookings': 0,
        'pendingBookings': 0,
        'completedJobs': 0,
      };
    }
  }

  // Search providers by category and location
  static Future<List<app_provider.Provider>> searchProvidersByLocation({
    String? category,
    Map<String, double>? userLocation,
    double radiusKm = 50.0,
  }) async {
    try {
      Query query = _firestore.collection('providers');
      
      query = query.where('status', isEqualTo: 'active');
      
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.get();
      List<app_provider.Provider> providers = snapshot.docs.map((doc) {
        return app_provider.Provider.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }).toList();

      // Filter by location if provided
      if (userLocation != null) {
        providers = providers.where((provider) {
          if (provider.lat == 0.0 && provider.lng == 0.0) return false;
          
          final distance = _calculateDistanceStatic(
            userLocation['latitude']!,
            userLocation['longitude']!,
            provider.lat,
            provider.lng,
          );
          
          return distance <= radiusKm;
        }).toList();

        // Sort by distance
        providers.sort((a, b) {
          final distanceA = _calculateDistanceStatic(
            userLocation['latitude']!,
            userLocation['longitude']!,
            a.lat,
            a.lng,
          );
          final distanceB = _calculateDistanceStatic(
            userLocation['latitude']!,
            userLocation['longitude']!,
            b.lat,
            b.lng,
          );
          return distanceA.compareTo(distanceB);
        });
      }

      return providers;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error searching providers: $e');
      return [];
    }
  }

  // Calculate distance between two coordinates (Haversine formula) - static version
  static double _calculateDistanceStatic(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
        cos(_toRadians(lat2)) *
        sin(dLon / 2) *
        sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get provider by ID
  static Future<app_provider.Provider?> getProviderById(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      if (doc.exists && doc.data() != null) {
        return app_provider.Provider.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting provider: $e');
      return null;
    }
  }

  // Get providers by category
  static Future<List<app_provider.Provider>> getProvidersByCategory({
    required String category,
    int limit = 20,
    String? lastDocumentId,
  }) async {
    try {
      Query query = _firestore
          .collection('providers')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit);

      if (lastDocumentId != null) {
        final lastDoc = await _firestore
            .collection('providers')
            .doc(lastDocumentId)
            .get();
        query = query.startAfterDocument(lastDoc);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        return app_provider.Provider.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting providers by category: $e');
      return [];
    }
  }

  // Get nearby providers
  static Future<List<app_provider.Provider>> getNearbyProviders({
    required double latitude,
    required double longitude,
    double maxDistance = 50.0, // km
    int limit = 20,
  }) async {
    try {
      // This is a simplified approach. In production, you'd use
      // Firestore's GeoPoint queries or a geospatial service
      final querySnapshot = await _firestore
          .collection('providers')
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();

      final providers = querySnapshot.docs.map((doc) {
        return app_provider.Provider.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }).toList();

      // Filter by distance and sort
      final nearbyProviders = providers.where((provider) {
        if (provider.lat == 0.0 && provider.lng == 0.0) return false;
        
        final distance = _calculateDistanceStatic(
          latitude,
          longitude,
          provider.lat,
          provider.lng,
        );
        
        return distance <= maxDistance;
      }).toList();

      // Sort by distance
      nearbyProviders.sort((a, b) {
        final distanceA = _calculateDistanceStatic(
          latitude,
          longitude,
          a.lat,
          a.lng,
        );
        final distanceB = _calculateDistanceStatic(
          latitude,
          longitude,
          b.lat,
          b.lng,
        );
        return distanceA.compareTo(distanceB);
      });

      return nearbyProviders;
    } catch (e) {
      debugPrint('Error getting nearby providers: $e');
      return [];
    }
  }

  // Get top rated providers
  static Future<List<app_provider.Provider>> getTopRatedProviders({
    int limit = 20,
    String? category,
  }) async {
    try {
      Query query = _firestore
          .collection('providers')
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit);

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        return app_provider.Provider.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting top rated providers: $e');
      return [];
    }
  }

  // Search providers by text query
  static Future<List<app_provider.Provider>> searchProviders({
    required String query,
    String? category,
    double? minRating,
    int limit = 20,
  }) async {
    try {
      Query queryRef = _firestore
          .collection('providers')
          .where('isActive', isEqualTo: true);

      if (category != null) {
        queryRef = queryRef.where('category', isEqualTo: category);
      }

      if (minRating != null) {
        queryRef = queryRef.where('rating', isGreaterThanOrEqualTo: minRating);
      }

      final querySnapshot = await queryRef.limit(limit).get();
      final providers = querySnapshot.docs.map((doc) {
        return app_provider.Provider.fromMap(doc.data()! as Map<String, dynamic>, id: doc.id);
      }).toList();

      // Filter by search query
      final searchResults = providers.where((provider) {
        final searchLower = query.toLowerCase();
        
        // Search in business name
        if (provider.businessName.toLowerCase().contains(searchLower)) {
          return true;
        }
        
        // Search in service names
        for (final service in provider.services) {
          if (service.title.toLowerCase().contains(searchLower)) {
            return true;
          }
        }
        
        // Search in category
        if (provider.categoryId.toLowerCase().contains(searchLower)) {
          return true;
        }
        
        // Search in description
        if (provider.description.toLowerCase().contains(searchLower)) {
          return true;
        }
        
        return false;
      }).toList();

      return searchResults;
    } catch (e) {
      debugPrint('Error searching providers: $e');
      return [];
    }
  }

  // Get provider statistics
  static Future<Map<String, dynamic>> getProviderStats(String providerId) async {
    try {
      final provider = await getProviderById(providerId);
      if (provider == null) {
        throw Exception('app_provider.Provider not found');
      }

      // Get reviews
      final reviews = await review_service.ReviewService.getProviderReviews(
        providerId: providerId,
        limit: 1000, // Get all reviews for stats
      );

      // Calculate statistics
      final totalReviews = reviews.length;
      final averageRating = totalReviews > 0 
          ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews
          : 0.0;
      
      final ratingDistribution = <int, int>{};
      for (int i = 1; i <= 5; i++) {
        ratingDistribution[i] = reviews.where((r) => r.rating == i).length;
      }

      // Get recent activity
      final recentBookings = await _getRecentBookings(providerId);
      final completedJobs = await _getCompletedJobs(providerId);

      return {
        'totalReviews': totalReviews,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
        'recentBookings': recentBookings,
        'completedJobs': completedJobs,
        'responseRate': 0.0, // TODO: Calculate from actual data
        'completionRate': 0.0, // TODO: Calculate from actual data
      };
    } catch (e) {
      debugPrint('Error getting provider stats: $e');
      return {};
    }
  }

  // Update provider profile
  static Future<void> updateProviderProfile({
    required String providerId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore
          .collection('providers')
          .doc(providerId)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating provider profile: $e');
      rethrow;
    }
  }

  // Add service to provider
  static Future<void> addService({
    required String providerId,
    required ServiceOffering service,
  }) async {
    try {
      await _firestore
          .collection('providers')
          .doc(providerId)
          .update({
        'services': FieldValue.arrayUnion([service.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding service: $e');
      rethrow;
    }
  }

  // Update service
  static Future<void> updateService({
    required String providerId,
    required String serviceId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final provider = await getProviderById(providerId);
      if (provider == null) {
        throw Exception('app_provider.Provider not found');
      }

      final updatedServices = provider.services.map((service) {
        if (service.title == serviceId) { // Using title as identifier
          return app_provider.Service(
            serviceId: service.serviceId,
            title: updates['title'] ?? service.title,
            priceFrom: updates['priceFrom'] ?? service.priceFrom,
            priceTo: updates['priceTo'] ?? service.priceTo,
            durationMin: updates['durationMin'] ?? service.durationMin,
          );
        }
        return service;
      }).toList();

      await _firestore
          .collection('providers')
          .doc(providerId)
          .update({
        'services': updatedServices.map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating service: $e');
      rethrow;
    }
  }

  // Delete service
  static Future<void> deleteService({
    required String providerId,
    required String serviceId,
  }) async {
    try {
      final provider = await getProviderById(providerId);
      if (provider == null) {
        throw Exception('app_provider.Provider not found');
      }

      final updatedServices = provider.services
          .where((service) => service.title != serviceId)
          .toList();

      await _firestore
          .collection('providers')
          .doc(providerId)
          .update({
        'services': updatedServices.map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error deleting service: $e');
      rethrow;
    }
  }

  // Get recent bookings for provider
  static Future<List<Map<String, dynamic>>> _getRecentBookings(String providerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data()! as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting recent bookings: $e');
      return [];
    }
  }

  // Get completed jobs for provider
  static Future<List<Map<String, dynamic>>> _getCompletedJobs(String providerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data()! as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting completed jobs: $e');
      return [];
    }
  }


}
