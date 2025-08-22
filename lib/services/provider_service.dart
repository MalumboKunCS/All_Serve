import 'dart:io';
import 'dart:math' as Math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/models/booking.dart';

class ProviderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get provider profile
  Future<Provider?> getProvider(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      if (doc.exists) {
        return Provider.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting provider: $e');
      return null;
    }
  }

  // Create provider profile
  Future<bool> createProvider({
    required String uid,
    required String email,
    required String businessName,
    required String category,
    required String description,
    String? ownerName,
    String? phone,
  }) async {
    try {
      final provider = Provider(
        id: uid,
        email: email,
        businessName: businessName,
        ownerName: ownerName,
        category: category,
        description: description,
        phone: phone,
        status: ProviderStatus.pending,
        verificationStatus: VerificationStatus.notSubmitted,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('providers').doc(uid).set(provider.toMap());
      return true;
    } catch (e) {
      print('Error creating provider: $e');
      return false;
    }
  }

  // Update provider profile
  Future<bool> updateProvider({
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
        final imageUrl = await _uploadImage(providerId, 'profile', profileImage);
        updateData['profileImageUrl'] = imageUrl;
      }

      if (businessLogo != null) {
        final logoUrl = await _uploadImage(providerId, 'logo', businessLogo);
        updateData['businessLogoUrl'] = logoUrl;
      }

      await _firestore.collection('providers').doc(providerId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating provider: $e');
      return false;
    }
  }

  // Upload image to Firebase Storage
  Future<String> _uploadImage(String providerId, String type, File imageFile) async {
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
      print('Error updating online status: $e');
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
      print('Error updating services: $e');
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
      print('Error uploading verification documents: $e');
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
  Stream<List<Booking>> getProviderBookings(String providerId) {
    return _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Booking.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get provider earnings
  Future<Map<String, dynamic>> getProviderEarnings(String providerId) async {
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
        final data = doc.data();
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
      print('Error getting provider earnings: $e');
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
          .where((doc) => doc.data()['status'] == BookingStatus.completed.name)
          .length;

      return {
        'totalBookings': totalBookings,
        'thisMonthBookings': thisMonthBookingsCount,
        'pendingBookings': pendingBookingsCount,
        'completedJobs': completedJobs,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'totalBookings': 0,
        'thisMonthBookings': 0,
        'pendingBookings': 0,
        'completedJobs': 0,
      };
    }
  }

  // Search providers by category and location
  Future<List<Provider>> searchProviders({
    String? category,
    Map<String, double>? userLocation,
    double radiusKm = 50.0,
  }) async {
    try {
      Query query = _firestore.collection('providers');
      
      query = query.where('status', isEqualTo: ProviderStatus.verified.name);
      
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.get();
      List<Provider> providers = snapshot.docs.map((doc) {
        return Provider.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Filter by location if provided
      if (userLocation != null) {
        providers = providers.where((provider) {
          if (provider.location == null) return false;
          
          final distance = _calculateDistance(
            userLocation['latitude']!,
            userLocation['longitude']!,
            provider.location!['latitude']!,
            provider.location!['longitude']!,
          );
          
          return distance <= radiusKm;
        }).toList();

        // Sort by distance
        providers.sort((a, b) {
          final distanceA = _calculateDistance(
            userLocation['latitude']!,
            userLocation['longitude']!,
            a.location!['latitude']!,
            a.location!['longitude']!,
          );
          final distanceB = _calculateDistance(
            userLocation['latitude']!,
            userLocation['longitude']!,
            b.location!['latitude']!,
            b.location!['longitude']!,
          );
          return distanceA.compareTo(distanceB);
        });
      }

      return providers;
    } catch (e) {
      print('Error searching providers: $e');
      return [];
    }
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) *
        Math.cos(_toRadians(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    
    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (Math.pi / 180);
  }
}
