import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get random categories from Firebase
  Future<List<Map<String, dynamic>>> getRandomCategories(int limit) async {
    try {
      // Get all categories from Firestore
      QuerySnapshot querySnapshot = await _firestore.collection('categories').get();
      
      if (querySnapshot.docs.isEmpty) {
        // Return default categories if none exist in Firebase
        return [
          {'icon': 'plumbing', 'label': 'Plumbing', 'id': 'plumbing'},
          {'icon': 'car_repair', 'label': 'Auto Repair', 'id': 'auto_repair'},
          {'icon': 'cleaning_services', 'label': 'Cleaning', 'id': 'cleaning'},
          {'icon': 'electrical', 'label': 'Electrical', 'id': 'electrical'},
          {'icon': 'carpentry', 'label': 'Carpentry', 'id': 'carpentry'},
          {'icon': 'gardening', 'label': 'Gardening', 'id': 'gardening'},
          {'icon': 'painting', 'label': 'Painting', 'id': 'painting'},
          {'icon': 'hvac', 'label': 'HVAC', 'id': 'hvac'},
        ];
      }

      // Convert to list and shuffle
      List<Map<String, dynamic>> categories = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'icon': data['icon'] ?? 'build',
          'label': data['label'] ?? 'Service',
        };
      }).toList();

      // Shuffle and return limited number
      categories.shuffle(Random());
      return categories.take(limit).toList();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error fetching categories: $e');
      // Return default categories on error
      return [
        {'icon': 'plumbing', 'label': 'Plumbing', 'id': 'plumbing'},
        {'icon': 'car_repair', 'label': 'Auto Repair', 'id': 'auto_repair'},
        {'icon': 'cleaning_services', 'label': 'Cleaning', 'id': 'cleaning'},
      ];
    }
  }

  // Get user's previous service providers
  Future<List<String>> getUserPreviousProviders(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<String> providerIds = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['providerId'] != null) {
          providerIds.add(data['providerId']);
        }
      }
      return providerIds;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error fetching user previous providers: $e');
      return [];
    }
  }

  // Get nearby service providers based on location
  Future<List<Map<String, dynamic>>> getNearbyProviders(
      double latitude, double longitude, double radiusInKm) async {
    try {
      // Get all providers and filter by distance
      QuerySnapshot querySnapshot = await _firestore.collection('providers').get();
      
      List<Map<String, dynamic>> nearbyProviders = [];
      
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (data['location'] != null && 
            data['location']['latitude'] != null && 
            data['location']['longitude'] != null) {
          
          double providerLat = data['location']['latitude'];
          double providerLng = data['location']['longitude'];
          
          double distance = Geolocator.distanceBetween(
            latitude, longitude, providerLat, providerLng);
          
          if (distance <= radiusInKm * 1000) { // Convert km to meters
            nearbyProviders.add({
              'id': doc.id,
              'name': data['name'] ?? 'Provider',
              'rating': data['rating'] ?? 0.0,
              'reviews': data['reviews'] ?? 0,
              'image': data['image'] ?? 'https://i.imgur.com/QCNbOAo.png',
              'distance': distance / 1000, // Convert to km
              'services': data['services'] ?? [],
              'location': data['location'],
            });
          }
        }
      }
      
      // Sort by distance
      nearbyProviders.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      return nearbyProviders;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error fetching nearby providers: $e');
      return [];
    }
  }

  // Get recommended providers (previous + nearby)
  Future<List<Map<String, dynamic>>> getRecommendedProviders(String userId) async {
    try {
      // Get user's current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
      
      // Get previous providers
      List<String> previousProviderIds = await getUserPreviousProviders(userId);
      
      // Get nearby providers
      List<Map<String, dynamic>> nearbyProviders = await getNearbyProviders(
        position.latitude, position.longitude, 50.0); // 50km radius
      
      // Get previous providers details
      List<Map<String, dynamic>> previousProviders = [];
      if (previousProviderIds.isNotEmpty) {
        for (String providerId in previousProviderIds.take(5)) {
          DocumentSnapshot doc = await _firestore
              .collection('providers')
              .doc(providerId)
              .get();
          
          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            previousProviders.add({
              'id': doc.id,
              'name': data['name'] ?? 'Provider',
              'rating': data['rating'] ?? 0.0,
              'reviews': data['reviews'] ?? 0,
              'image': data['image'] ?? 'https://i.imgur.com/QCNbOAo.png',
              'isPrevious': true,
              'services': data['services'] ?? [],
            });
          }
        }
      }
      
      // Combine and prioritize previous providers
      List<Map<String, dynamic>> recommendedProviders = [];
      recommendedProviders.addAll(previousProviders);
      
      // Add nearby providers that weren't in previous list
      for (var nearby in nearbyProviders) {
        if (!previousProviderIds.contains(nearby['id'])) {
          nearby['isPrevious'] = false;
          recommendedProviders.add(nearby);
        }
      }
      
      // Limit to 10 providers
      return recommendedProviders.take(10).toList();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting recommended providers: $e');
      // Return default providers on error
      return [
        {
          'name': 'John Smith',
          'rating': 4.8,
          'reviews': 120,
          'image': 'https://i.imgur.com/QCNbOAo.png',
          'isPrevious': false,
        },
        {
          'name': 'AutoCare Center',
          'rating': 4.7,
          'reviews': 95,
          'image': 'https://i.imgur.com/QCNbOAo.png',
          'isPrevious': false,
        },
        {
          'name': 'Sparkle Cleaners',
          'rating': 4.6,
          'reviews': 210,
          'image': 'https://i.imgur.com/QCNbOAo.png',
          'isPrevious': false,
        },
      ];
    }
  }

  // Get all categories
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('categories').get();
      
      if (querySnapshot.docs.isEmpty) {
        return [
          {'icon': 'plumbing', 'label': 'Plumbing', 'id': 'plumbing'},
          {'icon': 'car_repair', 'label': 'Auto Repair', 'id': 'auto_repair'},
          {'icon': 'cleaning_services', 'label': 'Cleaning', 'id': 'cleaning'},
          {'icon': 'electrical', 'label': 'Electrical', 'id': 'electrical'},
          {'icon': 'carpentry', 'label': 'Carpentry', 'id': 'carpentry'},
          {'icon': 'gardening', 'label': 'Gardening', 'id': 'gardening'},
          {'icon': 'painting', 'label': 'Painting', 'id': 'painting'},
          {'icon': 'hvac', 'label': 'HVAC', 'id': 'hvac'},
        ];
      }

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'icon': data['icon'] ?? 'build',
          'label': data['label'] ?? 'Service',
        };
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error fetching all categories: $e');
      return [];
    }
  }

  // Get providers by category with location and rating sorting
  Future<List<Map<String, dynamic>>> getProvidersByCategory(
      String categoryId, {bool sortByLocation = false}) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('providers')
          .where('services', arrayContains: categoryId)
          .get();
      
      List<Map<String, dynamic>> providers = [];
      
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        Map<String, dynamic> provider = {
          'id': doc.id,
          'name': data['name'] ?? 'Provider',
          'rating': data['rating'] ?? 0.0,
          'reviews': data['reviews'] ?? 0,
          'image': data['image'] ?? 'https://i.imgur.com/QCNbOAo.png',
          'services': data['services'] ?? [],
        };

        // Add location data if available
        if (data['location'] != null && 
            data['location']['latitude'] != null && 
            data['location']['longitude'] != null) {
          provider['location'] = data['location'];
        }

        providers.add(provider);
      }
      
      // Sort by rating (highest first) or by location if requested
      if (sortByLocation) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
          
          for (var provider in providers) {
            if (provider['location'] != null) {
              double distance = Geolocator.distanceBetween(
                position.latitude, 
                position.longitude, 
                provider['location']['latitude'], 
                provider['location']['longitude']
              );
              provider['distance'] = distance / 1000; // Convert to km
            }
          }
          
          // Sort by distance, providers without location go to the end
          providers.sort((a, b) {
            if (a['distance'] == null && b['distance'] == null) {
              return (b['rating'] as double).compareTo(a['rating'] as double);
            }
            if (a['distance'] == null) return 1;
            if (b['distance'] == null) return -1;
            return (a['distance'] as double).compareTo(b['distance'] as double);
          });
        } catch (e) {
          // ignore: avoid_print
          debugPrint('Error getting location, falling back to rating sort: $e');
          providers.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
        }
      } else {
        // Sort by rating (highest first)
        providers.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
      }
      
      return providers;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error fetching providers by category: $e');
      return [];
    }
  }
}
