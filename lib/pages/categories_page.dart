import 'package:flutter/material.dart';
import 'package:all_server/services/firebase_service.dart';
import 'package:all_server/utils/icon_helper.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final allCategories = await _firebaseService.getAllCategories();
      setState(() {
        categories = allCategories;
        isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error loading categories: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Service Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Refresh categories',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return GestureDetector(
                    onTap: () => _navigateToCategoryProviders(category),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              IconHelper.getIconFromString(category['icon']),
                              size: 40,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            category['label'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _navigateToCategoryProviders(Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryProvidersPage(category: category),
      ),
    );
  }
}

class CategoryProvidersPage extends StatefulWidget {
  final Map<String, dynamic> category;

  const CategoryProvidersPage({super.key, required this.category});

  @override
  State<CategoryProvidersPage> createState() => _CategoryProvidersPageState();
}

class _CategoryProvidersPageState extends State<CategoryProvidersPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> providers = [];
  bool isLoading = true;
  bool sortByLocation = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final categoryProviders = await _firebaseService.getProvidersByCategory(
        widget.category['id'],
        sortByLocation: sortByLocation,
      );
      setState(() {
        providers = categoryProviders;
        isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error loading providers: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleSorting() {
    setState(() {
      sortByLocation = !sortByLocation;
      isLoading = true;
    });
    _loadProviders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category['label']} Providers'),
        actions: [
          IconButton(
            icon: Icon(sortByLocation ? Icons.star : Icons.location_on),
            onPressed: _toggleSorting,
            tooltip: sortByLocation 
                ? 'Sort by rating' 
                : 'Sort by location',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProviders,
              child: providers.isEmpty
                  ? const Center(
                      child: Text(
                        'No providers found for this category',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: providers.length,
                      itemBuilder: (context, index) {
                        final provider = providers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(provider['image']),
                              radius: 30,
                            ),
                            title: Text(
                              provider['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      provider['rating'].toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
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
                                // Navigate to booking flow
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Booking ${provider['name']}...'),
                                  ),
                                );
                              },
                              child: const Text('Book'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

