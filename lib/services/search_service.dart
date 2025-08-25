import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:all_server/models/provider.dart';
import 'dart:math';

class SearchService {
  static const FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user location
  static Future<Map<String, double>> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      throw Exception('Failed to get current location: $e');
    }
  }
  
  // Search providers by keyword and location
  static Future<List<Provider>> searchProviders({
    required String query,
    String? category,
    double? userLatitude,
    double? userLongitude,
    double? maxDistance,
    double? minRating,
    int limit = 20,
  }) async {
    try {
      Query providersQuery = _firestore.collection('providers');
      
      // Filter by category if specified
      if (category != null && category.isNotEmpty) {
        providersQuery = providersQuery.where('category', isEqualTo: category);
      }
      
      // Filter by active status
      providersQuery = providersQuery.where('isActive', isEqualTo: true);
      
      // Filter by minimum rating if specified
      if (minRating != null && minRating > 0) {
        providersQuery = providersQuery.where('rating', isGreaterThanOrEqualTo: minRating);
      }
      
      // Get providers
      QuerySnapshot snapshot = await providersQuery.limit(limit).get();
      
      List<Provider> providers = [];
      
      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          final provider = Provider.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          
          // Calculate distance if location is available
          if (provider.location != null && userLatitude != null && userLongitude != null) {
            double distance = _calculateDistance(
              userLatitude,
              userLongitude,
              provider.location!.latitude,
              provider.location!.longitude,
            );
            
            // Filter by max distance if specified
            if (maxDistance != null && distance > maxDistance) {
              continue;
            }
          }
          
          // Check if provider matches search query
          if (_matchesSearchQuery(provider, query)) {
            providers.add(provider);
          }
        } catch (e) {
          debugPrint('Error parsing provider ${doc.id}: $e');
          continue;
        }
      }
      
      // Sort by relevance and distance
      providers.sort((a, b) {
        // First sort by relevance score
        int relevanceA = _calculateRelevanceScore(a, query);
        int relevanceB = _calculateRelevanceScore(b, query);
        
        if (relevanceA != relevanceB) {
          return relevanceB.compareTo(relevanceA);
        }
        
        // Then sort by rating
        if (a.rating != b.rating) {
          return b.rating.compareTo(a.rating);
        }
        
        // Finally sort by distance if available
        if (userLatitude != null && userLongitude != null && 
            a.location != null && b.location != null) {
          double distanceA = _calculateDistance(
            userLatitude, userLongitude,
            a.location!.latitude, a.location!.longitude,
          );
          double distanceB = _calculateDistance(
            userLatitude, userLongitude,
            b.location!.latitude, b.location!.longitude,
          );
          return distanceA.compareTo(distanceB);
        }
        
        return 0;
      });
      
      return providers;
    } catch (e) {
      debugPrint('Error searching providers: $e');
      return [];
    }
  }
  
  // Search by location only
  static Future<List<Provider>> searchByLocation({
    required double latitude,
    required double longitude,
    double maxDistance = 50.0, // 50km default
    String? category,
    int limit = 20,
  }) async {
    try {
      Query providersQuery = _firestore.collection('providers');
      
              if (category != null && category.isNotEmpty) {
          providersQuery = providersQuery.where('category', isEqualTo: category);
        }
      
      providersQuery = providersQuery.where('isActive', isEqualTo: true);
      
      QuerySnapshot snapshot = await providersQuery.limit(limit).get();
      
      List<Provider> providers = [];
      
      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          final provider = Provider.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          
          if (provider.location != null) {
            double distance = _calculateDistance(
              latitude,
              longitude,
              provider.location!.latitude,
              provider.location!.longitude,
            );
            
            if (distance <= maxDistance) {
              providers.add(provider);
            }
          }
        } catch (e) {
          debugPrint('Error parsing provider ${doc.id}: $e');
          continue;
        }
      }
      
      // Sort by distance
      providers.sort((a, b) {
        if (a.location == null || b.location == null) return 0;
        
        double distanceA = _calculateDistance(
          latitude, longitude,
          a.location!.latitude, a.location!.longitude,
        );
        double distanceB = _calculateDistance(
          latitude, longitude,
          b.location!.latitude, b.location!.longitude,
        );
        
        return distanceA.compareTo(distanceB);
      });
      
      return providers;
    } catch (e) {
      debugPrint('Error searching by location: $e');
      return [];
    }
  }
  
  // Search by category
  static Future<List<Provider>> searchByCategory({
    required String category,
    double? userLatitude,
    double? userLongitude,
    double? maxDistance,
    int limit = 20,
  }) async {
    try {
      Query providersQuery = _firestore.collection('providers')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit);
      
      QuerySnapshot snapshot = await providersQuery.get();
      
      List<Provider> providers = [];
      
      for (DocumentSnapshot doc in snapshot.docs) {
        try {
          final provider = Provider.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          
          // Calculate distance if location is available
          if (provider.location != null && userLatitude != null && userLongitude != null) {
            double distance = _calculateDistance(
              userLatitude,
              userLongitude,
              provider.location!.latitude,
              provider.location!.longitude,
            );
            
            // Filter by max distance if specified
            if (maxDistance != null && distance > maxDistance) {
              continue;
            }
          }
          
          providers.add(provider);
        } catch (e) {
          debugPrint('Error parsing provider ${doc.id}: $e');
          continue;
        }
      }
      
      return providers;
    } catch (e) {
      debugPrint('Error searching by category: $e');
      return [];
    }
  }
  
  // Get address from coordinates
  static Future<List<Placemark>> getAddressFromCoordinates(
    double latitude, double longitude) async {
    try {
      return await placemarkFromCoordinates(latitude, longitude);
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return [];
    }
  }
  
  // Get search suggestions
  static Future<List<String>> getSearchSuggestions() async {
    try {
      // This would typically come from a search suggestions collection
      // For now, return some common service categories
      return [
        'Plumbing',
        'Electrical',
        'Cleaning',
        'Gardening',
        'Painting',
        'Carpentry',
        'HVAC',
        'Roofing',
        'Moving',
        'Pet Care',
        'Tutoring',
        'Beauty',
        'Fitness',
        'Photography',
      ];
    } catch (e) {
      debugPrint('Error getting search suggestions: $e');
      return [];
    }
  }
  
  // Check if provider matches search query
  static bool _matchesSearchQuery(Provider provider, String query) {
    final searchLower = query.toLowerCase();
    
    // Search in business name
    if (provider.businessName.toLowerCase().contains(searchLower)) {
      return true;
    }
    
    // Search in service names
    for (final service in provider.services) {
      if (service.name.toLowerCase().contains(searchLower)) {
        return true;
      }
    }
    
         // Search in category
     if (provider.category.toLowerCase().contains(searchLower)) {
       return true;
     }
    
    // Search in description
    if (provider.description?.toLowerCase().contains(searchLower) == true) {
      return true;
    }
    
    return false;
  }
  
  // Calculate relevance score for search results
  static int _calculateRelevanceScore(Provider provider, String query) {
    final searchLower = query.toLowerCase();
    int score = 0;
    
    // Business name match (highest weight)
    if (provider.businessName.toLowerCase().contains(searchLower)) {
      score += 10;
    }
    
    // Service name match (high weight)
    for (final service in provider.services) {
      if (service.name.toLowerCase().contains(searchLower)) {
        score += 8;
      }
    }
    
         // Category match (medium weight)
     if (provider.category.toLowerCase().contains(searchLower)) {
       score += 5;
     }
    
    // Description match (low weight)
    if (provider.description?.toLowerCase().contains(searchLower) == true) {
      score += 2;
    }
    
         // Boost score for verified providers
     if (provider.verificationStatus == VerificationStatus.approved) {
       score += 3;
     }
    
    // Boost score for popular services
    for (final service in provider.services) {
      if (service.isPopular) {
        score += 2;
      }
    }
    
    return score;
  }
  
  // Calculate distance between two points
  static double _calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
