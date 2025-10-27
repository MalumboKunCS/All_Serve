import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart' as shared;
import '../../models/category.dart';
import '../../models/provider.dart' as app_provider;
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';
import 'categories_screen.dart';
import 'category_providers_screen.dart'; // Issue 7: For category filtering
import 'my_profile_screen.dart';
import 'provider_detail_screen.dart';
import 'advanced_search_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
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
      AppLogger.debug('Loading home screen data...');
      
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
        AppLogger.debug('No featured categories found, loading general categories...');
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

      AppLogger.debug('Loaded ${_featuredCategories.length} categories and ${_nearbyProviders.length} providers');

    } catch (e, stackTrace) {
      AppLogger.error('Error loading data: $e');
      AppLogger.error('Stack trace: $stackTrace');
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data. Please try again.'),
            backgroundColor: AppTheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadData,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Calculate optimal expanded height for SliverAppBar based on screen size
  double _getOptimalAppBarHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenType = ResponsiveUtils.getScreenType(context);
    
    // Base height calculation: ensure enough space for content
    double baseHeight;
    switch (screenType) {
      case ScreenType.mobile:
        baseHeight = 160.0; // Increased from 120 to prevent overflow
        break;
      case ScreenType.tablet:
        baseHeight = 180.0;
        break;
      case ScreenType.desktop:
        baseHeight = 200.0;
        break;
    }
    
    // Ensure the height doesn't exceed 25% of screen height
    final maxHeight = screenHeight * 0.25;
    return baseHeight > maxHeight ? maxHeight : baseHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: _isLoading
          ? _buildLoadingState()
          : _featuredCategories.isEmpty && _nearbyProviders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ResponsiveLayoutBuilder(
                    builder: (context, screenType) {
                      return CustomScrollView(
                    slivers: [
                  // Modern App Bar with Search
                  SliverAppBar(
                    expandedHeight: _getOptimalAppBarHeight(context),
                    floating: false,
                    pinned: true,
                    backgroundColor: AppTheme.surfaceDark,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: EdgeInsets.zero,
                      background: Stack(
                        children: [
                          // Gradient background
                          Container(
                            decoration: const BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                            ),
                          ),
                          // All-Serve watermark (subtle background text)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                'All-Serve',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  fontWeight: FontWeight.bold,
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: 60,
                                    tablet: 70,
                                    desktop: 80,
                                  ),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          // Welcome content
                          SafeArea(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: ResponsiveUtils.getResponsiveSpacing(
                                      context,
                                      mobile: 20,
                                      tablet: 24,
                                      desktop: 32,
                                    ),
                                    right: ResponsiveUtils.getResponsiveSpacing(
                                      context,
                                      mobile: 20,
                                      tablet: 24,
                                      desktop: 32,
                                    ),
                                    top: constraints.maxHeight * 0.35,
                                    bottom: 20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Welcome back!',
                                        style: AppTheme.bodyLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                                            context,
                                            mobile: 18,
                                            tablet: 20,
                                            desktop: 22,
                                          ),
                                          height: 1.3,
                                        ),
                                      ),
                                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                                        context,
                                        mobile: 6,
                                        tablet: 8,
                                        desktop: 10,
                                      )),
                                      Text(
                                        'Find trusted local service providers',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: Colors.grey[200],
                                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                                            context,
                                            mobile: 14,
                                            tablet: 16,
                                            desktop: 18,
                                          ),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
        actions: [
          // Notifications Icon
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
                        icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                              builder: (_) => const MyProfileScreen(),
                ),
              );
            },
          ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'logout') {
                            try {
                              final authService = context.read<shared.AuthService>();
                              await authService.signOut();
                              
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            } catch (e) {
                              AppLogger.error('Logout error: $e');
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
                            value: 'logout',
                            child: Text('Logout'),
                                    ),
                                  ],
          ),
        ],
      ),

                  // Main Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveUtils.getResponsivePadding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 20,
                            tablet: 24,
                            desktop: 28,
                          )),
                          // Prominent Search Section
                          _buildSearchSection(),
                          
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 28,
                            tablet: 32,
                            desktop: 36,
                          )),
                          
                          // Service Categories Grid
                          _buildCategoriesSection(),
                          
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 28,
                            tablet: 32,
                            desktop: 36,
                          )),
                          
                          // Featured Providers
                          _buildProvidersSection(),
                          
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 40,
                            tablet: 48,
                            desktop: 56,
                          )), // Bottom padding for navigation
                        ],
                      ),
                    ),
                  ),
                ],
              );
                },
              ),
            ),
      bottomNavigationBar: ResponsiveLayoutBuilder(
        builder: (context, screenType) {
          return BottomNavigationBar(
        backgroundColor: AppTheme.surfaceDark,
        selectedItemColor: AppTheme.primaryPurple,
        unselectedItemColor: AppTheme.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedFontSize: ResponsiveUtils.getResponsiveFontSize(
          context,
          mobile: 12,
          tablet: 13,
          desktop: 14,
        ),
        unselectedFontSize: ResponsiveUtils.getResponsiveFontSize(
          context,
          mobile: 11,
          tablet: 12,
          desktop: 13,
        ),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        iconSize: ResponsiveUtils.getResponsiveIconSize(
          context,
          mobile: 24,
          tablet: 26,
          desktop: 28,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyProfileScreen(),
                ),
              );
              break;
          }
        },
      );
        },
      ),
    );
  }

  Widget _buildSearchSection() {
    return ResponsiveContainer(
      padding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 16,
            tablet: 18,
            desktop: 20,
          )),
          border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdvancedSearchScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            )),
            splashColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
            highlightColor: AppTheme.primaryPurple.withValues(alpha: 0.05),
            child: Padding(
              padding: ResponsiveUtils.getResponsivePadding(context),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.search,
                      color: Colors.white,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 24,
                        tablet: 26,
                        desktop: 28,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  )),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Services',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 16,
                              tablet: 18,
                              desktop: 20,
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 4,
                          tablet: 5,
                          desktop: 6,
                        )),
                        Text(
                          "Try 'Electrician', 'Plumber'...",
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey[500],
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 13,
                              tablet: 15,
                              desktop: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.textTertiary,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Categories',
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CategoriesScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    ),
                    vertical: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 8,
                      tablet: 10,
                      desktop: 12,
                    ),
                  ),
                ),
                icon: Icon(
                  Icons.arrow_forward,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
                label: Text(
                  'View All',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.accentBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.accentBlue.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        )),
        _featuredCategories.isEmpty
            ? _buildEmptyCategoriesState()
            : ResponsiveGridView(
                crossAxisSpacing: ResponsiveUtils.getResponsiveGridSpacing(context),
                mainAxisSpacing: ResponsiveUtils.getResponsiveGridSpacing(context),
                childAspectRatio: ResponsiveUtils.getResponsiveGridChildAspectRatio(context),
                padding: EdgeInsets.zero,
                children: _featuredCategories.map((category) => _buildCategoryCard(category)).toList(),
              ),
      ],
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        // Issue 7: Navigate to category-filtered providers
        onTap: () {
          try {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryProvidersScreen(category: category),
              ),
            );
          } catch (e) {
            AppLogger.error('Error navigating to category providers: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to open category providers'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: ResponsiveUtils.getResponsiveIconSize(
                  context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                height: ResponsiveUtils.getResponsiveIconSize(
                  context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.category,
                  color: Colors.white,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: AppTheme.spacingMd,
                tablet: AppTheme.spacingLg,
                desktop: AppTheme.spacingXl,
              )),
              Text(
                category.name,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProvidersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Providers',
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdvancedSearchScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    ),
                    vertical: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 8,
                      tablet: 10,
                      desktop: 12,
                    ),
                  ),
                ),
                icon: Icon(
                  Icons.arrow_forward,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
                label: Text(
                  'View All',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.accentBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.accentBlue.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        )),
        _nearbyProviders.isEmpty
            ? _buildEmptyProvidersState()
            : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _nearbyProviders.length,
                      itemBuilder: (context, index) {
                        final provider = _nearbyProviders[index];
            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
              decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  try {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProviderDetailScreen(
                          provider: provider,
                        ),
                      ),
                    );
                  } catch (e) {
                    AppLogger.error('Error navigating to provider detail: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unable to open provider details'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  child: Row(
                    children: [
                      // Provider Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: (provider.logoUrl != null && provider.logoUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  provider.logoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.business,
                                      color: AppTheme.primaryPurple,
                                      size: 28,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.business,
                                color: AppTheme.primaryPurple,
                                size: 28,
                              ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      // Provider Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.businessName,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingXs),
                                Text(
                                  provider.description,
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondary,
                                fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            const SizedBox(height: AppTheme.spacingSm),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: AppTheme.warning,
                                    ),
                                const SizedBox(width: AppTheme.spacingXs),
                                Text(
                                  provider.ratingAvg.toStringAsFixed(1),
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingSm),
                                    Text(
                                  '(${provider.ratingCount} reviews)',
                                      style: AppTheme.caption.copyWith(
                                        color: AppTheme.textTertiary,
                                    fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      ),
                      Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.textTertiary,
                              size: 16,
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

  Widget _buildEmptyCategoriesState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'No categories available',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Categories will appear here once they are added',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProvidersState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'No providers found nearby',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Try adjusting your search location or check back later',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdvancedSearchScreen(),
                          ),
                        );
                      },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLg,
                vertical: AppTheme.spacingMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Search Providers'),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: _getOptimalAppBarHeight(context),
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.surfaceDark,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'All-Serve',
              style: AppTheme.heading3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
              ),
            ),
            centerTitle: true,
            titlePadding: const EdgeInsets.only(bottom: 16),
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
          ),
        ),
        // Empty Content
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 80,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to All-Serve',
                    style: AppTheme.heading2.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No services are available at the moment. Please check back later or contact support.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: _getOptimalAppBarHeight(context),
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.surfaceDark,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'All-Serve',
              style: AppTheme.heading3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
              ),
            ),
            centerTitle: true,
            titlePadding: const EdgeInsets.only(bottom: 16),
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
          ),
        ),
        // Loading Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                // Search Section Skeleton
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                // Categories Section Skeleton
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 150,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppTheme.spacingMd,
                    mainAxisSpacing: AppTheme.spacingMd,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacingXl),
                // Providers Section Skeleton
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 150,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Provider Cards Skeleton
                ...List.generate(3, (index) => Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
