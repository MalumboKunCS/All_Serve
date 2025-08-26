import 'package:flutter/material.dart';
import 'package:all_server/services/search_service.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/pages/provider_detail_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  List<Provider> searchResults = [];
  List<String> searchSuggestions = [];
  List<String> categories = [
    'Plumbing', 'Electrical', 'Cleaning', 'Gardening', 'Painting',
    'Carpentry', 'HVAC', 'Roofing', 'Landscaping', 'Moving',
    'Pet Care', 'Tutoring', 'Beauty', 'Fitness', 'Photography'
  ];
  
  String? selectedCategory;
  double? maxDistance;
  double? minRating;
  Position? userLocation;
  String? userAddress;
  bool isSearching = false;
  bool hasSearched = false;
  bool showFilters = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadSearchSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = position;
      });

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await SearchService.getAddressFromCoordinates(
          position.latitude, 
          position.longitude
        );
        if (placemarks.isNotEmpty) {
          String address = '${placemarks.first.locality}, ${placemarks.first.administrativeArea}';
          setState(() {
            userAddress = address;
            _locationController.text = address;
          });
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadSearchSuggestions() async {
    try {
      List<String> suggestions = await SearchService.getSearchSuggestions();
      setState(() {
        searchSuggestions = suggestions;
      });
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
    }
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) {
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
      List<Provider> results = await SearchService.searchProviders(
        query: _searchController.text.trim(),
        category: selectedCategory,
        userLatitude: userLocation?.latitude,
        userLongitude: userLocation?.longitude,
        maxDistance: maxDistance,
        minRating: minRating,
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

  void _clearFilters() {
    setState(() {
      selectedCategory = null;
      maxDistance = null;
      minRating = null;
      showFilters = false;
    });
  }

  void _applyFilters() {
    setState(() {
      showFilters = false;
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Services'),
        actions: [
          IconButton(
            icon: Icon(showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: () {
              setState(() {
                showFilters = !showFilters;
              });
            },
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Input
                TextField(
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
                              _performSearch();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _performSearch(),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      _performSearch();
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Location Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on),
                          hintText: "Enter location or use current",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          // Handle location input
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _getUserLocation,
                      icon: const Icon(Icons.my_location),
                      tooltip: 'Use current location',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _performSearch,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
          ),
          
          // Filters Section
          if (showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Category Filter
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: categories.map((category) {
                      bool isSelected = selectedCategory == category;
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            selectedCategory = selected ? category : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Distance Filter
                  const Text(
                    'Maximum Distance',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: maxDistance ?? 50.0,
                    min: 1.0,
                    max: 100.0,
                    divisions: 99,
                    label: '${(maxDistance ?? 50.0).round()} km',
                    onChanged: (value) {
                      setState(() {
                        maxDistance = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Rating Filter
                  const Text(
                    'Minimum Rating',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: minRating ?? 0.0,
                    min: 0.0,
                    max: 5.0,
                    divisions: 10,
                    label: (minRating ?? 0.0).toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        minRating = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apply Filters Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          
          // Search Results
          Expanded(
            child: hasSearched
                ? _buildSearchResults()
                : _buildSearchSuggestions(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchResults.isEmpty) {
      return const Center(
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
                'Try adjusting your search criteria or filters',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final provider = searchResults[index];
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
                          provider.location!['latitude']!,
                          provider.location!['longitude']!,
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
      },
    );
  }

  Widget _buildSearchSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Popular Searches',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (searchSuggestions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: searchSuggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                onPressed: () {
                  _searchController.text = suggestion;
                  _performSearch();
                },
              );
            }).toList(),
          ),
        
        const SizedBox(height: 24),
        
        const Text(
          'Browse by Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return Card(
              child: InkWell(
                onTap: () {
                  _searchController.text = category;
                  _performSearch();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        size: 32,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'gardening':
        return Icons.eco;
      case 'painting':
        return Icons.brush;
      case 'carpentry':
        return Icons.handyman;
      case 'hvac':
        return Icons.ac_unit;
      case 'roofing':
        return Icons.home;
      case 'landscaping':
        return Icons.landscape;
      case 'moving':
        return Icons.local_shipping;
      case 'pet care':
        return Icons.pets;
      case 'tutoring':
        return Icons.school;
      case 'beauty':
        return Icons.face;
      case 'fitness':
        return Icons.fitness_center;
      case 'photography':
        return Icons.camera_alt;
      default:
        return Icons.work;
    }
  }

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
    return degrees * (pi / 180);
  }
}
