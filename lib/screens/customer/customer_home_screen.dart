import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart' as shared;
import '../../models/category.dart';
import '../../models/provider.dart' as app_provider;
import 'categories_screen.dart';
import 'my_profile_screen.dart';
import 'provider_detail_screen.dart';
import 'advanced_search_screen.dart';
import 'my_bookings_screen.dart';
import '../auth/login_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  List<Category> _featuredCategories = [];
  List<app_provider.Provider> _nearbyProviders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      // Run Firestore queries in parallel and offload to a microtask
      // to avoid blocking the initial frame
      // Load featured categories
      final categoriesFuture = FirebaseFirestore.instance
          .collection('categories')
          .where('isFeatured', isEqualTo: true)
          .limit(3)
          .get();

      // Load nearby providers (for now, active verified providers)
      final providersFuture = FirebaseFirestore.instance
          .collection('providers')
          .where('status', isEqualTo: 'active')
          .where('verified', isEqualTo: true)
          .orderBy('ratingAvg', descending: true)
          .limit(5)
          .get();

      final results = await Future.wait([categoriesFuture, providersFuture]);
      final categoriesSnapshot = results[0] as QuerySnapshot;
      final providersSnapshot = results[1] as QuerySnapshot;

      _featuredCategories = categoriesSnapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();

      // If no featured categories, get first 3 categories
      if (_featuredCategories.isEmpty) {
        final allCategoriesSnapshot = await FirebaseFirestore.instance
            .collection('categories')
            .limit(3)
            .get();

        _featuredCategories = allCategoriesSnapshot.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();
      }

      _nearbyProviders = providersSnapshot.docs
          .map((doc) => app_provider.Provider.fromFirestore(doc))
          .toList();

    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('All-Serve'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdvancedSearchScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyProfileScreen(),
                  ),
                );
              } else if (value == 'logout') {
                try {
                  final authService = context.read<shared.AuthService>();
                  await authService.signOut();
                  
                  // Navigate to login screen and clear navigation stack
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  // ignore: avoid_print
                  print('Logout error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('Profile'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to All-Serve',
                            style: AppTheme.heading1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Find trusted local service providers',
                            style: AppTheme.bodyLarge.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Featured Categories
                    Text(
                      'Featured Categories',
                      style: AppTheme.heading2.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _featuredCategories.length,
                        itemBuilder: (context, index) {
                          final category = _featuredCategories[index];
                          return Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardDark,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.category,
                                    color: AppTheme.primaryPurple,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  category.name,
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Nearby Providers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nearby Providers',
                          style: AppTheme.heading2.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdvancedSearchScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'View All',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _nearbyProviders.length,
                      itemBuilder: (context, index) {
                        final provider = _nearbyProviders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppTheme.cardDark,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (provider.logoUrl != null && provider.logoUrl!.isNotEmpty)
                                  ? NetworkImage(provider.logoUrl!)
                                  : null,
                              child: (provider.logoUrl == null || provider.logoUrl!.isEmpty)
                                  ? Icon(
                                      Icons.business,
                                      color: AppTheme.primaryPurple,
                                    )
                                  : null,
                            ),
                            title: Text(
                              provider.businessName,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.description,
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: AppTheme.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${provider.ratingAvg.toStringAsFixed(1)} (${provider.ratingCount})',
                                      style: AppTheme.caption.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.textTertiary,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProviderDetailScreen(
                                    provider: provider,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.surfaceDark,
        selectedItemColor: AppTheme.primaryPurple,
        unselectedItemColor: AppTheme.textTertiary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CategoriesScreen(),
                ),
              );
              break;
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyBookingsScreen(),
                ),
              );
              break;
            case 3:
              // TODO: Navigate to profile
              break;
          }
        },
      ),
    );
  }
}
