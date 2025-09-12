import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/search_service.dart';
import '../../services/location_service.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/category.dart';
import 'provider_detail_screen.dart';

class AdvancedSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? categoryId;

  const AdvancedSearchScreen({
    super.key,
    this.initialQuery,
    this.categoryId,
  });

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  late TabController _tabController;

  // Search state
  List<app_provider.Provider> _providers = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  Position? _userLocation;

  // Filters
  SearchFilters _filters = SearchFilters();
  final List<String> _selectedFeatures = [];
  bool _showFilters = false;

  // UI state
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _lastQuery = widget.initialQuery!;
    }

    _filters = SearchFilters(
      categoryId: widget.categoryId,
      sortBy: SortBy.relevance,
    );

    _initializeLocation();
    _setupScrollListener();
    
    if (widget.initialQuery != null) {
      _performSearch();
    } else {
      _loadTrendingProviders();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _initializeLocation() async {
    try {
      final location = await LocationService().getCurrentLocation();
      setState(() => _userLocation = location);
      
      // Update filters with location
      _filters = SearchFilters(
        query: _filters.query,
        categoryId: _filters.categoryId,
        userLocation: location,
        maxDistance: _filters.maxDistance,
        minRating: _filters.minRating,
        maxPrice: _filters.maxPrice,
        isVerified: _filters.isVerified,
        serviceIds: _filters.serviceIds,
        sortBy: _filters.sortBy,
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search App Bar
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: true,
            backgroundColor: AppTheme.surfaceDark,
            title: _buildSearchBar(),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildTabBar(),
            ),
            actions: [
              IconButton(
                onPressed: _toggleFilters,
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: _hasActiveFilters() ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          // Filters Panel
          if (_showFilters) _buildFiltersPanel(),

          // Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProvidersTab(),
                _buildCategoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search services, providers...',
          hintStyle: TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: AppTheme.backgroundDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        style: const TextStyle(color: AppTheme.textPrimary),
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppTheme.accent,
      unselectedLabelColor: AppTheme.textSecondary,
      indicatorColor: AppTheme.accent,
      tabs: const [
        Tab(text: 'Providers'),
        Tab(text: 'Categories'),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return SliverToBoxAdapter(
      child: Container(
        color: AppTheme.surfaceDark,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),

            // Distance filter
            _buildDistanceFilter(),
            const SizedBox(height: 16),

            // Rating filter
            _buildRatingFilter(),
            const SizedBox(height: 16),

            // Price filter
            _buildPriceFilter(),
            const SizedBox(height: 16),

            // Feature keywords (select 1-3)
            _buildFeatureFilter(),
            const SizedBox(height: 16),

            // Verification filter
            _buildVerificationFilter(),
            const SizedBox(height: 16),

            // Sort options
            _buildSortOptions(),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: AppTheme.outlineButtonStyle,
                    child: const Text('Clear All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: AppTheme.primaryButtonStyle,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maximum Distance: ${_filters.maxDistance.round()} km',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        ),
        Slider(
          value: _filters.maxDistance,
          min: 1,
          max: 100,
          divisions: 99,
          activeColor: AppTheme.accent,
          inactiveColor: AppTheme.textTertiary,
          onChanged: (value) {
            setState(() {
              _filters = SearchFilters(
                query: _filters.query,
                categoryId: _filters.categoryId,
                userLocation: _filters.userLocation,
                maxDistance: value,
                minRating: _filters.minRating,
                maxPrice: _filters.maxPrice,
                isVerified: _filters.isVerified,
                serviceIds: _filters.serviceIds,
                sortBy: _filters.sortBy,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Minimum Rating',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [0.0, 3.0, 4.0, 4.5].map((rating) {
            final isSelected = _filters.minRating == rating;
            return FilterChip(
              label: Text(rating == 0.0 ? 'Any' : '${rating}+ ⭐'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _filters = SearchFilters(
                    query: _filters.query,
                    categoryId: _filters.categoryId,
                    userLocation: _filters.userLocation,
                    maxDistance: _filters.maxDistance,
                    minRating: selected ? (rating == 0.0 ? null : rating) : null,
                    maxPrice: _filters.maxPrice,
                    isVerified: _filters.isVerified,
                    serviceIds: _filters.serviceIds,
                    sortBy: _filters.sortBy,
                  );
                });
              },
              backgroundColor: AppTheme.backgroundDark,
              selectedColor: AppTheme.accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maximum Price Range',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [null, 100.0, 500.0, 1000.0, 5000.0].map((price) {
            final isSelected = _filters.maxPrice == price;
            return FilterChip(
              label: Text(price == null ? 'Any' : 'K${price.toInt()}'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _filters = SearchFilters(
                    query: _filters.query,
                    categoryId: _filters.categoryId,
                    userLocation: _filters.userLocation,
                    maxDistance: _filters.maxDistance,
                    minRating: _filters.minRating,
                    maxPrice: selected ? price : null,
                    isVerified: _filters.isVerified,
                    serviceIds: _filters.serviceIds,
                    sortBy: _filters.sortBy,
                  );
                });
              },
              backgroundColor: AppTheme.backgroundDark,
              selectedColor: AppTheme.accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVerificationFilter() {
    return Row(
      children: [
        Checkbox(
          value: _filters.isVerified ?? false,
          onChanged: (value) {
            setState(() {
              _filters = SearchFilters(
                query: _filters.query,
                categoryId: _filters.categoryId,
                userLocation: _filters.userLocation,
                maxDistance: _filters.maxDistance,
                minRating: _filters.minRating,
                maxPrice: _filters.maxPrice,
                isVerified: value,
                serviceIds: _filters.serviceIds,
                sortBy: _filters.sortBy,
              );
            });
          },
          activeColor: AppTheme.accent,
        ),
        Text(
          'Verified providers only',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sort By',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: SortBy.values.toList().map((sortBy) {
            final isSelected = _filters.sortBy == sortBy;
            return FilterChip(
              label: Text(_getSortDisplayName(sortBy)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filters = SearchFilters(
                      query: _filters.query,
                      categoryId: _filters.categoryId,
                      userLocation: _filters.userLocation,
                      maxDistance: _filters.maxDistance,
                      minRating: _filters.minRating,
                      maxPrice: _filters.maxPrice,
                      isVerified: _filters.isVerified,
                      serviceIds: _filters.serviceIds,
                      sortBy: sortBy,
                    );
                  });
                }
              },
              backgroundColor: AppTheme.backgroundDark,
              selectedColor: AppTheme.accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFeatureFilter() {
    // Static features list; in production could be dynamic from Firestore
    final features = <String>[
      '24/7', 'Emergency', 'Eco-friendly', 'Warranty', 'Certified',
      'Mobile', 'On-site', 'Fast', 'Budget', 'Premium',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features (select 1-3)',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((f) {
            final isSelected = _selectedFeatures.contains(f);
            return FilterChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (_selectedFeatures.length < 3) {
                      _selectedFeatures.add(f);
                    }
                  } else {
                    _selectedFeatures.remove(f);
                  }
                });
              },
              backgroundColor: AppTheme.backgroundDark,
              selectedColor: AppTheme.accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProvidersTab() {
    if (_isLoading && _providers.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_providers.isEmpty) {
      return _buildEmptyProvidersState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _providers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${_providers.length} providers found',
                  style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                ),
                const Spacer(),
                if (_userLocation == null)
                  TextButton.icon(
                    onPressed: _initializeLocation,
                    icon: Icon(Icons.location_on, color: AppTheme.accent),
                    label: Text('Enable Location', style: TextStyle(color: AppTheme.accent)),
                  ),
              ],
            ),
          );
        }

        final listIndex = index - 1;
        if (listIndex == _providers.length) {
          if (!_isLoadingMore) return const SizedBox.shrink();
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        return _buildProviderCard(_providers[listIndex]);
      },
    );
  }

  Widget _buildCategoriesTab() {
    if (_isLoading && _categories.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_categories.isEmpty) {
      return _buildEmptyCategoriesState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        return _buildCategoryCard(_categories[index]);
      },
    );
  }

  Widget _buildProviderCard(app_provider.Provider provider) {
    double? distance;
    if (_userLocation != null) {
      distance = _calculateDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        provider.lat,
        provider.lng,
      );
    }

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToProvider(provider),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Provider logo
              ClipOval(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: (provider.logoUrl?.isNotEmpty ?? false)
                      ? CachedNetworkImage(
                          imageUrl: provider.logoUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          fadeInDuration: Duration.zero,
                          placeholder: (context, _) => Container(color: AppTheme.primary.withValues(alpha: 0.2)),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.primary,
                            child: const Icon(Icons.business, color: Colors.white),
                          ),
                        )
                      : Container(
                          color: AppTheme.primary,
                          child: const Icon(Icons.business, color: Colors.white),
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Provider info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.businessName,
                            style: AppTheme.bodyText.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (provider.verified)
                          Icon(Icons.verified, color: AppTheme.success, size: 16),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      provider.description,
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(Icons.star, color: AppTheme.warning, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.ratingAvg.toStringAsFixed(1)} (${provider.ratingCount})',
                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                        ),
                        
                        if (distance != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.location_on, color: AppTheme.info, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToCategory(category),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  _getCategoryIcon(category.name),
                  color: AppTheme.accent,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      category.description,
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProvidersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No providers found',
            style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoriesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No categories found',
            style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  // Event handlers
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.length < 2 || value == _lastQuery) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _onSearchSubmitted(value);
    });
  }

  void _onSearchSubmitted(String value) {
    _performSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _lastQuery = '';
    });
    _loadTrendingProviders();
  }

  void _toggleFilters() {
    setState(() => _showFilters = !_showFilters);
  }

  void _clearFilters() {
    setState(() {
      _filters = SearchFilters(
        query: _filters.query,
        categoryId: widget.categoryId,
        userLocation: _userLocation,
        sortBy: SortBy.relevance,
      );
    });
  }

  void _applyFilters() {
    setState(() => _showFilters = false);
    _performSearch();
  }

  // Search methods
  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMore = true;
      _providers.clear();
    });

    try {
      final updatedFilters = SearchFilters(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        categoryId: _filters.categoryId,
        userLocation: _filters.userLocation,
        maxDistance: _filters.maxDistance,
        minRating: _filters.minRating,
        maxPrice: _filters.maxPrice,
        isVerified: _filters.isVerified,
        serviceIds: _filters.serviceIds,
        featureKeywords: _selectedFeatures.isEmpty ? null : List<String>.from(_selectedFeatures),
        sortBy: _filters.sortBy,
      );

      final result = await SearchService.searchProviders(
        query: updatedFilters.query,
        categoryId: updatedFilters.categoryId,
        userLocation: updatedFilters.userLocation,
        maxDistance: updatedFilters.maxDistance,
        minRating: updatedFilters.minRating,
        maxPrice: updatedFilters.maxPrice,
        isVerified: updatedFilters.isVerified,
        serviceIds: updatedFilters.serviceIds,
        featureKeywords: updatedFilters.featureKeywords,
        sortBy: updatedFilters.sortBy,
        limit: 20,
        offset: 0,
      );

      setState(() {
        _providers = result.providers;
        _hasMore = result.hasMore;
        _currentOffset = result.providers.length;
        _filters = updatedFilters;
        _lastQuery = _searchController.text;
      });

      // Also search categories if there's a query
      if (_searchController.text.trim().isNotEmpty) {
        _searchCategories(_searchController.text.trim());
      }
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await SearchService.searchProviders(
        query: _filters.query,
        categoryId: _filters.categoryId,
        userLocation: _filters.userLocation,
        maxDistance: _filters.maxDistance,
        minRating: _filters.minRating,
        maxPrice: _filters.maxPrice,
        isVerified: _filters.isVerified,
        serviceIds: _filters.serviceIds,
        featureKeywords: _filters.featureKeywords,
        sortBy: _filters.sortBy,
        limit: 20,
        offset: _currentOffset,
      );

      setState(() {
        _providers.addAll(result.providers);
        _hasMore = result.hasMore;
        _currentOffset += result.providers.length;
      });
    } catch (e) {
      print('Load more error: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadTrendingProviders() async {
    setState(() => _isLoading = true);

    try {
      final providers = await SearchService.getTrendingProviders(
        userLocation: _userLocation,
        categoryId: widget.categoryId,
        limit: 20,
      );

      setState(() {
        _providers = providers;
        _hasMore = false;
      });
    } catch (e) {
      print('Error loading trending providers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchCategories(String query) async {
    try {
      final categories = await SearchService.searchCategories(query);
      setState(() => _categories = List<Category>.from(categories));
    } catch (e) {
      print('Error searching categories: $e');
    }
  }

  // Suggestions functionality removed for simplicity
  // Could be re-implemented later if needed

  // Navigation
  void _navigateToProvider(app_provider.Provider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderDetailScreen(provider: provider),
      ),
    );
  }

  void _navigateToCategory(Category category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdvancedSearchScreen(
          categoryId: category.categoryId,
          initialQuery: category.name,
        ),
      ),
    );
  }

  // Utility methods
  bool _hasActiveFilters() {
    return _filters.minRating != null ||
           _filters.maxPrice != null ||
           _filters.isVerified != null ||
           _filters.maxDistance < 50.0 ||
           _filters.sortBy != SortBy.relevance ||
           _selectedFeatures.isNotEmpty;
  }

  String _getSortDisplayName(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.relevance:
        return 'Relevance';
      case SortBy.distance:
        return 'Distance';
      case SortBy.rating:
        return 'Rating';
      case SortBy.priceAsc:
        return 'Price: Low to High';
      case SortBy.priceDesc:
        return 'Price: High to Low';
      case SortBy.newest:
        return 'Newest';
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'gardening':
        return Icons.yard;
      case 'home repair':
        return Icons.home_repair_service;
      case 'painting':
        return Icons.format_paint;
      case 'carpentry':
        return Icons.handyman;
      case 'beauty':
        return Icons.face;
      case 'fitness':
        return Icons.fitness_center;
      case 'tutoring':
        return Icons.school;
      default:
        return Icons.work;
    }
  }

  // Helper method for distance calculation
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
}
