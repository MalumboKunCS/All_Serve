import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/services/firebase_service.dart';
import 'package:all_server/services/search_service.dart';
import 'package:all_server/utils/icon_helper.dart';
import 'package:all_server/pages/categories_page.dart';
import 'package:all_server/pages/settings_page.dart';
import 'package:all_server/pages/provider_detail_page.dart';
import 'package:all_server/pages/search_page.dart';
import 'package:all_server/models/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = Auth().currentUser;
  final FirebaseService _firebaseService = FirebaseService();
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> providers = [];
  List<Provider> searchResults = [];
  bool isLoading = true;
  bool isSearching = false;
  bool hasSearched = false;
  Position? userLocation;
  String? userAddress;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get user's current location
  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = position;
      });

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await _searchService.getAddressFromCoordinates(
          position.latitude, 
          position.longitude
        );
        if (placemarks.isNotEmpty) {
          setState(() {
            userAddress = '${placemarks.first.locality}, ${placemarks.first.administrativeArea}';
          });
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // Load categories and providers data
  Future<void> _loadData() async {
    try {
      // Load random categories
      final randomCategories = await _firebaseService.getRandomCategories(6);
      
      // Load recommended providers
      final recommendedProviders = await _firebaseService.getRecommendedProviders(
        user?.uid ?? 'anonymous');
      
      setState(() {
        categories = randomCategories;
        providers = recommendedProviders;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Perform search
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
    });

    try {
      List<Provider> results = await _searchService.searchProviders(
        query: query,
        userLatitude: userLocation?.latitude,
        userLongitude: userLocation?.longitude,
        maxDistance: 50.0, // 50km radius
      );

      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching: $e');
      setState(() {
        isSearching = false;
        searchResults = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  // Sign out function
  Future<void> signOut() async {
    await Auth().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ALL SERVE", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: signOut,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Search Section
                  const Text(
                    "What service do you need?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Enhanced Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: "Search services, providers, or categories...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _performSearch('');
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: _performSearch,
                          onChanged: (value) {
                            if (value.isEmpty) {
                              _performSearch('');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _performSearch(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Search'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune),
                        tooltip: 'Advanced Search',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  
                  // Location Display
                  if (userAddress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Searching near: $userAddress',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Search Results Section
                  if (hasSearched) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Search Results (${searchResults.length})",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (searchResults.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                hasSearched = false;
                                searchResults = [];
                                _searchController.clear();
                              });
                            },
                            child: const Text('Clear Search'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (isSearching)
                      const Center(child: CircularProgressIndicator())
                    else if (searchResults.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No providers found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try different keywords or expand your search area',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: searchResults.map((provider) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: provider.profileImageUrl != null
                                    ? NetworkImage(provider.profileImageUrl!)
                                    : null,
                                radius: 24,
                                child: provider.profileImageUrl == null
                                    ? Text(
                                        provider.businessName.isNotEmpty
                                            ? provider.businessName[0].toUpperCase()
                                            : 'P',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                                                             title: Text(
                                 provider.businessName.isNotEmpty
                                     ? provider.businessName
                                     : provider.ownerName ?? 'Provider',
                                 style: const TextStyle(fontWeight: FontWeight.bold),
                               ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (provider.services.isNotEmpty)
                                    Text(
                                      provider.services.first.name,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Text(
                                        provider.rating.toStringAsFixed(1),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      Text(' (${provider.reviewCount})'),
                                      if (provider.location != null && userLocation != null)
                                        Text(
                                          ' • ${_calculateDistance(
                                            userLocation!.latitude,
                                            userLocation!.longitude,
                                            provider.location!.latitude,
                                            provider.location!.longitude,
                                          ).toStringAsFixed(1)} km',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                                                             trailing: ElevatedButton(
                                 onPressed: () {
                                   Navigator.push(
                                     context,
                                     MaterialPageRoute(
                                       builder: (context) => ProviderDetailPage(providerId: provider.id),
                                     ),
                                   );
                                 },
                                 child: const Text('View'),
                               ),
                            ),
                          );
                        }).toList(),
                      ),
                    
                    const SizedBox(height: 20),
                  ],
                  
                  // Categories Section
                  if (!hasSearched) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoriesPage(),
                          ),
                        );
                      },
                      child: const Text("View categories", style: TextStyle(color: Colors.blue)),
                    ),
                    const SizedBox(height: 20),
                    const Text("Book an Appointment Instantly", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (categories.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(
                            height: 120,
                            child: PageView.builder(
                              itemCount: (categories.length / 3).ceil(),
                              itemBuilder: (context, pageIndex) {
                                final startIndex = pageIndex * 3;
                                final endIndex = (startIndex + 3).clamp(0, categories.length);
                                final pageCategories = categories.sublist(startIndex, endIndex);
                                
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: pageCategories.map((cat) {
                                    return Expanded(
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor: Colors.blue.shade100,
                                            child: Icon(
                                              IconHelper.getIconFromString(cat['icon']), 
                                              size: 30, 
                                              color: Colors.blue
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            cat['label'],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              (categories.length / 3).ceil(),
                              (index) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == 0 ? Colors.blue : Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const Center(child: Text('No categories available')),
                    
                    const SizedBox(height: 20),
                    
                    // Suggested Providers Section
                    const Text("Suggested Providers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (providers.isNotEmpty)
                      Column(
                        children: providers.map((provider) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(provider['image']),
                                radius: 24,
                              ),
                              title: Row(
                                children: [
                                  Text(provider['name']),
                                  if (provider['isPrevious'] == true)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Previous',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(provider['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      Text(' (${provider['reviews']})'),
                                    ],
                                  ),
                                  if (provider['distance'] != null)
                                    Text(
                                      '${provider['distance'].toStringAsFixed(1)} km away',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Navigate to provider details page
                                },
                                child: const Text('View'),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      const Center(child: Text('No providers available')),
                  ],
                ],
              ),
            ),
    );
  }

  // Calculate distance between two points
  double _calculateDistance(
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

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}
