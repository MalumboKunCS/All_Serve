import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../models/provider.dart' as app_provider;
import '../models/category.dart';


class SearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Advanced search with comprehensive filtering and ranking
  static Future<SearchResult> searchProviders({
    String? query,
    String? categoryId,
    Position? userLocation,
    double? maxDistance,
    double? minRating,
    double? maxPrice,
    bool? isVerified,
    List<String>? serviceIds,
    SortBy sortBy = SortBy.relevance,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final searchFilters = SearchFilters(
        query: query,
        categoryId: categoryId,
        userLocation: userLocation,
        maxDistance: maxDistance ?? 50.0, // Default 50km
        minRating: minRating,
        maxPrice: maxPrice,
        isVerified: isVerified,
        serviceIds: serviceIds,
        sortBy: sortBy,
      );

      // Step 1: Get base providers with basic filters
      final providers = await _getFilteredProviders(searchFilters, limit + offset);

      // Step 2: Apply advanced filtering and ranking
      final scoredProviders = await _scoreAndFilterProviders(providers, searchFilters);

      // Step 3: Sort by selected criteria
      _sortProviders(scoredProviders, sortBy);

      // Step 4: Apply pagination
      final paginatedProviders = scoredProviders
          .skip(offset)
          .take(limit)
          .map((sp) => sp.provider)
          .toList();

      return SearchResult(
        providers: paginatedProviders,
        totalCount: scoredProviders.length,
        hasMore: scoredProviders.length > offset + limit,
        filters: searchFilters,
      );
    } catch (e) {
      print('Error in advanced search: $e');
      return SearchResult(
        providers: [],
        totalCount: 0,
        hasMore: false,
        filters: SearchFilters(),
      );
    }
  }

  /// Get trending/popular providers based on recent bookings and ratings
  static Future<List<app_provider.Provider>> getTrendingProviders({
    Position? userLocation,
    String? categoryId,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore.collection('providers')
          .where('status', isEqualTo: 'active')
          .where('verified', isEqualTo: true);

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      final snapshot = await query
          .orderBy('trendingScore', descending: true)
          .limit(limit * 2) // Get more for filtering
          .get();

      final providers = snapshot.docs
          .map((doc) => app_provider.Provider.fromFirestore(doc))
          .toList();

      // Apply location filtering if needed
      if (userLocation != null) {
        providers.removeWhere((provider) {
          final distance = _calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            provider.lat,
            provider.lng,
          );
          return distance > 50.0; // 50km radius
        });
      }

      return providers.take(limit).toList();
        } catch (e) {
      print('Error getting trending providers: $e');
      return [];
    }
  }

  /// Search with autocomplete suggestions
  static Future<List<SearchSuggestion>> getSearchSuggestions(
    String query, {
    Position? userLocation,
    int limit = 10,
  }) async {
    if (query.length < 2) return [];

    try {
      final suggestions = <SearchSuggestion>[];
      final queryLower = query.toLowerCase();

      // Get category suggestions
      final categories = await _getCategorySuggestions(queryLower, limit ~/ 2);
      suggestions.addAll(categories);

      // Get provider suggestions
      final providers = await _getProviderSuggestions(queryLower, userLocation, limit ~/ 2);
      suggestions.addAll(providers);

      // Get service suggestions
      final services = await _getServiceSuggestions(queryLower, limit ~/ 2);
      suggestions.addAll(services);

      // Sort by relevance
      suggestions.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return suggestions.take(limit).toList();
    } catch (e) {
      print('Error getting search suggestions: $e');
      return [];
    }
  }
  
  /// Get providers within a specific area using geohash
  static Future<List<app_provider.Provider>> getProvidersInArea({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    String? categoryId,
    int limit = 50,
  }) async {
    try {
      // Calculate geohash bounds
      final geohashBounds = _getGeohashBounds(centerLat, centerLng, radiusKm);
      
      Query query = _firestore.collection('providers')
          .where('status', isEqualTo: 'active');

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      // Use geohash for initial filtering
      query = query
          .where('geohash', isGreaterThanOrEqualTo: geohashBounds.southwest)
          .where('geohash', isLessThanOrEqualTo: geohashBounds.northeast);

      final snapshot = await query.limit(limit * 2).get();

      final providers = snapshot.docs
          .map((doc) => app_provider.Provider.fromFirestore(doc))
          .where((provider) {
            final distance = _calculateDistance(
              centerLat,
              centerLng,
              provider.lat,
              provider.lng,
            );
            return distance <= radiusKm;
          })
          .toList();
      
      // Sort by distance
      providers.sort((a, b) {
        final distanceA = _calculateDistance(
          centerLat, centerLng,
          a.lat, a.lng,
        );
        final distanceB = _calculateDistance(
          centerLat, centerLng,
          b.lat, b.lng,
        );
        return distanceA.compareTo(distanceB);
      });
      
      return providers.take(limit).toList();
    } catch (e) {
      print('Error getting providers in area: $e');
      return [];
    }
  }
  
  /// Get all categories (compatibility method)
  static Future<List<Category>> getCategories({bool? isFeatured}) async {
    try {
      Query query = _firestore.collection('categories');
      if (isFeatured != null) {
        query = query.where('isFeatured', isEqualTo: isFeatured);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
        } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }
  
  /// Get providers by category (compatibility method)
  static Future<List<app_provider.Provider>> getProvidersByCategory(
    String categoryId, {
    Position? userLocation,
    int limit = 20,
  }) async {
    final result = await searchProviders(
      categoryId: categoryId,
      userLocation: userLocation,
      limit: limit,
    );
    return result.providers;
  }

  /// Enhanced category search with sub-categories
  static Future<List<Category>> searchCategories(String query) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();
      
      // Get all categories for client-side filtering (more flexible)
      final snapshot = await _firestore.collection('categories').get();
      
      final categories = snapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .where((category) {
            final nameMatch = category.name.toLowerCase().contains(queryLower);
            final descMatch = category.description.toLowerCase().contains(queryLower);
            // Note: Category model doesn't have tags field
            final tagsMatch = false;
            
            return nameMatch || descMatch || tagsMatch;
          })
          .toList();

      // Sort by relevance
      categories.sort((a, b) {
        final aScore = _calculateCategoryRelevance(a, queryLower);
        final bScore = _calculateCategoryRelevance(b, queryLower);
        return bScore.compareTo(aScore);
      });

      return categories;
    } catch (e) {
      print('Error searching categories: $e');
      return [];
    }
  }
  
  /// Get similar providers based on category and services
  static Future<List<app_provider.Provider>> getSimilarProviders(
    app_provider.Provider provider, {
    Position? userLocation,
    int limit = 5,
  }) async {
    try {
      Query query = _firestore.collection('providers')
          .where('status', isEqualTo: 'active')
          .where('categoryId', isEqualTo: provider.categoryId)
          .where(FieldPath.documentId, isNotEqualTo: provider.providerId);

      final snapshot = await query.limit(limit * 2).get();

      final providers = snapshot.docs
          .map((doc) => app_provider.Provider.fromFirestore(doc))
          .toList();

      // Score similarity
      final scoredProviders = providers.map((p) {
        double score = 0.0;

        // Category match (already filtered)
        score += 1.0;

        // Service similarity
        final commonServices = provider.services
            .where((s) => p.services.any((ps) => ps.title == s.title))
            .length;
        score += (commonServices / provider.services.length) * 0.5;

        // Rating similarity
        final ratingDiff = (provider.ratingAvg - p.ratingAvg).abs();
        score += math.max(0, 1 - (ratingDiff / 5)) * 0.3;

        // Location proximity (if available)
        if (userLocation != null) {
          final distance = _calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            p.lat,
            p.lng,
          );
          score += math.max(0, 1 - (distance / 50)) * 0.2;
        }

        return ScoredProvider(provider: p, score: score, distance: 0);
      }).toList();

      scoredProviders.sort((a, b) => b.score.compareTo(a.score));

      return scoredProviders
          .take(limit)
          .map((sp) => sp.provider)
          .toList();
    } catch (e) {
      print('Error getting similar providers: $e');
      return [];
    }
  }
  
  // Private helper methods

  static Future<List<app_provider.Provider>> _getFilteredProviders(
    SearchFilters filters,
    int limit,
  ) async {
    Query query = _firestore.collection('providers')
        .where('status', isEqualTo: 'active');

    // Apply basic filters
    if (filters.categoryId != null) {
      query = query.where('categoryId', isEqualTo: filters.categoryId);
    }

    if (filters.isVerified != null) {
      query = query.where('verified', isEqualTo: filters.isVerified);
    }

    if (filters.minRating != null) {
      query = query.where('ratingAvg', isGreaterThanOrEqualTo: filters.minRating);
    }

    final snapshot = await query.limit(limit * 2).get(); // Get extra for filtering

    return snapshot.docs
        .map((doc) => app_provider.Provider.fromFirestore(doc))
        .toList();
  }

  static Future<List<ScoredProvider>> _scoreAndFilterProviders(
    List<app_provider.Provider> providers,
    SearchFilters filters,
  ) async {
    final scoredProviders = <ScoredProvider>[];

    for (final provider in providers) {
      // Calculate distance
      double distance = 0.0;
      if (filters.userLocation != null) {
        distance = _calculateDistance(
          filters.userLocation!.latitude,
          filters.userLocation!.longitude,
          provider.lat,
          provider.lng,
        );

        // Skip if outside max distance
        if (distance > filters.maxDistance) continue;
      }

      // Calculate relevance score
      final score = await _calculateProviderScore(provider, filters);

      // Apply additional filters
      if (!_passesAdditionalFilters(provider, filters)) continue;

      scoredProviders.add(ScoredProvider(
        provider: provider,
        score: score,
        distance: distance,
      ));
    }

    return scoredProviders;
  }

  static Future<double> _calculateProviderScore(
    app_provider.Provider provider,
    SearchFilters filters,
  ) async {
    double score = 0.0;

    // Base score from rating and popularity
    score += provider.ratingAvg / 5.0 * 0.3; // 30% weight for rating
    score += math.min(provider.ratingCount / 100.0, 1.0) * 0.1; // 10% for review count

    // Verification bonus
    if (provider.verified) {
      score += 0.2;
    }

    // Query relevance (if searching)
    if (filters.query != null && filters.query!.isNotEmpty) {
      final queryScore = _calculateQueryRelevance(provider, filters.query!);
      score += queryScore * 0.4; // 40% weight for query relevance
    }

    // Recent activity bonus
    final daysSinceCreated = DateTime.now().difference(provider.createdAt).inDays;
    if (daysSinceCreated < 30) {
      score += 0.1; // New provider bonus
    }

    // Service count bonus
    score += math.min(provider.services.length / 10.0, 0.1);

    return math.min(score, 1.0); // Cap at 1.0
  }

  static double _calculateQueryRelevance(app_provider.Provider provider, String query) {
    final queryLower = query.toLowerCase();
    double relevance = 0.0;

    // Business name match
    if (provider.businessName.toLowerCase().contains(queryLower)) {
      relevance += 0.4;
      if (provider.businessName.toLowerCase().startsWith(queryLower)) {
        relevance += 0.2; // Prefix bonus
      }
    }

    // Description match
    if (provider.description.toLowerCase().contains(queryLower)) {
      relevance += 0.2;
    }

    // Service titles match
    for (final service in provider.services) {
      if (service.title.toLowerCase().contains(queryLower)) {
        relevance += 0.3;
        break; // Only count once
      }
    }

    // Keywords/tags match
    if (provider.keywords.any((keyword) => 
        keyword.toLowerCase().contains(queryLower))) {
      relevance += 0.1;
    }

    return math.min(relevance, 1.0);
  }

  static bool _passesAdditionalFilters(
    app_provider.Provider provider,
    SearchFilters filters,
  ) {
    // Price filtering (check services)
    if (filters.maxPrice != null) {
      final hasAffordableService = provider.services.any((service) {
        return service.priceFrom <= filters.maxPrice!;
      });
      if (!hasAffordableService) return false;
    }

    // Service IDs filtering
    if (filters.serviceIds != null && filters.serviceIds!.isNotEmpty) {
      final hasRequiredService = provider.services.any((service) =>
          filters.serviceIds!.contains(service.serviceId));
      if (!hasRequiredService) return false;
    }

    return true;
  }

  static void _sortProviders(List<ScoredProvider> providers, SortBy sortBy) {
    switch (sortBy) {
      case SortBy.relevance:
        providers.sort((a, b) => b.score.compareTo(a.score));
        break;
      case SortBy.distance:
        providers.sort((a, b) => a.distance.compareTo(b.distance));
        break;
      case SortBy.rating:
        providers.sort((a, b) => b.provider.ratingAvg.compareTo(a.provider.ratingAvg));
        break;
      case SortBy.priceAsc:
        providers.sort((a, b) {
          final aMin = a.provider.services.isNotEmpty 
              ? a.provider.services.map((s) => s.priceFrom).reduce(math.min)
              : 0.0;
          final bMin = b.provider.services.isNotEmpty 
              ? b.provider.services.map((s) => s.priceFrom).reduce(math.min)
              : 0.0;
          return aMin.compareTo(bMin);
        });
        break;
      case SortBy.priceDesc:
        providers.sort((a, b) {
          final aMax = a.provider.services.isNotEmpty 
              ? a.provider.services.map((s) => s.priceTo).reduce(math.max)
              : 0.0;
          final bMax = b.provider.services.isNotEmpty 
              ? b.provider.services.map((s) => s.priceTo).reduce(math.max)
              : 0.0;
          return bMax.compareTo(aMax);
        });
        break;
      case SortBy.newest:
        providers.sort((a, b) => b.provider.createdAt.compareTo(a.provider.createdAt));
        break;
    }
  }

  // Suggestion methods
  static Future<List<SearchSuggestion>> _getCategorySuggestions(
    String query,
    int limit,
  ) async {
    final snapshot = await _firestore
        .collection('categories')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + 'z')
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final category = Category.fromFirestore(doc);
      return SearchSuggestion(
        text: category.name,
        type: SuggestionType.category,
        data: {'categoryId': category.categoryId},
        relevanceScore: _calculateTextRelevance(category.name, query),
      );
    }).toList();
  }

  static Future<List<SearchSuggestion>> _getProviderSuggestions(
    String query,
    Position? userLocation,
    int limit,
  ) async {
    final snapshot = await _firestore
        .collection('providers')
        .where('businessName', isGreaterThanOrEqualTo: query)
        .where('businessName', isLessThan: query + 'z')
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final provider = app_provider.Provider.fromFirestore(doc);
      double distance = 0.0;
      
      if (userLocation != null) {
        distance = _calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          provider.lat,
          provider.lng,
        );
      }

      return SearchSuggestion(
        text: provider.businessName,
        type: SuggestionType.provider,
        data: {
          'providerId': provider.providerId,
          'distance': distance,
        },
        relevanceScore: _calculateTextRelevance(provider.businessName, query),
      );
    }).toList();
  }

  static Future<List<SearchSuggestion>> _getServiceSuggestions(
    String query,
    int limit,
  ) async {
    // This would require a separate services collection or denormalized data
    // For now, return empty list
    return [];
  }

  // Utility methods
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  static GeohashBounds _getGeohashBounds(double lat, double lng, double radiusKm) {
    // Simplified geohash bounds calculation
    // In production, use a proper geohash library
    final latDiff = radiusKm / 111.0; // Approximate km per degree latitude
    final lngDiff = radiusKm / (111.0 * math.cos(_toRadians(lat)));

    return GeohashBounds(
      southwest: _encodeGeohash(lat - latDiff, lng - lngDiff),
      northeast: _encodeGeohash(lat + latDiff, lng + lngDiff),
    );
  }

  static String _encodeGeohash(double lat, double lng) {
    // Simplified geohash encoding - use proper library in production
    return '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
  }

  static double _calculateTextRelevance(String text, String query) {
    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();

    if (textLower == queryLower) return 1.0;
    if (textLower.startsWith(queryLower)) return 0.8;
    if (textLower.contains(queryLower)) return 0.6;
    
    return 0.0;
  }

  static double _calculateCategoryRelevance(Category category, String query) {
    double score = 0.0;

    if (category.name.toLowerCase().contains(query)) {
      score += 0.6;
      if (category.name.toLowerCase().startsWith(query)) {
        score += 0.3;
      }
    }

    if (category.description.toLowerCase().contains(query)) {
      score += 0.1;
    }

    return score;
  }
}

// Data classes
class SearchResult {
  final List<app_provider.Provider> providers;
  final int totalCount;
  final bool hasMore;
  final SearchFilters filters;

  SearchResult({
    required this.providers,
    required this.totalCount,
    required this.hasMore,
    required this.filters,
  });
}

class SearchFilters {
  final String? query;
  final String? categoryId;
  final Position? userLocation;
  final double maxDistance;
  final double? minRating;
  final double? maxPrice;
  final bool? isVerified;
  final List<String>? serviceIds;
  final SortBy sortBy;

  SearchFilters({
    this.query,
    this.categoryId,
    this.userLocation,
    this.maxDistance = 50.0,
    this.minRating,
    this.maxPrice,
    this.isVerified,
    this.serviceIds,
    this.sortBy = SortBy.relevance,
  });
}

class ScoredProvider {
  final app_provider.Provider provider;
  final double score;
  final double distance;

  ScoredProvider({
    required this.provider,
    required this.score,
    required this.distance,
  });
}

class SearchSuggestion {
  final String text;
  final SuggestionType type;
  final Map<String, dynamic> data;
  final double relevanceScore;

  SearchSuggestion({
    required this.text,
    required this.type,
    required this.data,
    required this.relevanceScore,
  });
}

class GeohashBounds {
  final String southwest;
  final String northeast;

  GeohashBounds({
    required this.southwest,
    required this.northeast,
  });
}

enum SortBy {
  relevance,
  distance,
  rating,
  priceAsc,
  priceDesc,
  newest,
}

enum SuggestionType {
  category,
  provider,
  service,
}
