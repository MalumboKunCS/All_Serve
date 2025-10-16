import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../models/category.dart';
import '../../models/provider.dart' as app_provider;
import '../../services/search_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_logger.dart';
import 'provider_detail_screen.dart';

class CategoryProvidersScreen extends StatefulWidget {
  final Category category;

  const CategoryProvidersScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryProvidersScreen> createState() => _CategoryProvidersScreenState();
}

class _CategoryProvidersScreenState extends State<CategoryProvidersScreen> {
  List<app_provider.Provider> _providers = [];
  bool _isLoading = true;
  Position? _userLocation;
  final LocationService _locationService = LocationService();
  String _sortBy = 'distance'; // 'distance' | 'rating' | 'name'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _getCurrentLocation();
    await _loadProviders();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (hasPermission) {
        _userLocation = await _locationService.getCurrentLocation();
      }
    } catch (e) {
      AppLogger.error('Error getting location: $e');
    }
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await SearchService.getProvidersByCategory(
        widget.category.categoryId,
        userLocation: _userLocation,
      );
      
      if (mounted) {
        setState(() {
          _providers = providers;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading providers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load providers: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _sortProviders() {
    setState(() {
      switch (_sortBy) {
        case 'distance':
          if (_userLocation != null) {
            _providers.sort((a, b) {
              final distanceA = _locationService.calculateDistance(
                _userLocation!.latitude,
                _userLocation!.longitude,
                a.lat,
                a.lng,
              );
              final distanceB = _locationService.calculateDistance(
                _userLocation!.latitude,
                _userLocation!.longitude,
                b.lat,
                b.lng,
              );
              return distanceA.compareTo(distanceB);
            });
          }
          break;
        case 'rating':
          _providers.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
          break;
        case 'name':
          _providers.sort((a, b) => a.businessName.compareTo(b.businessName));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('${widget.category.name} Providers'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _sortProviders();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'distance',
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _sortBy == 'distance' ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sort by Distance',
                      style: TextStyle(
                        color: _sortBy == 'distance' ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rating',
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: _sortBy == 'rating' ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sort by Rating',
                      style: TextStyle(
                        color: _sortBy == 'rating' ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      color: _sortBy == 'name' ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sort by Name',
                      style: TextStyle(
                        color: _sortBy == 'name' ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _providers.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _providers.length,
                      itemBuilder: (context, index) {
                        final provider = _providers[index];
                        return _buildProviderCard(provider);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
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
            'No ${widget.category.name} providers found',
            style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try checking back later or explore other categories',
            style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: AppTheme.primaryButtonStyle,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(app_provider.Provider provider) {
    String? distance;
    if (_userLocation != null) {
      final distanceKm = _locationService.calculateDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        provider.lat,
        provider.lng,
      );
      distance = _locationService.formatDistance(distanceKm);
    }

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProviderDetailScreen(provider: provider),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Logo/Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primary,
                backgroundImage: (provider.logoUrl?.isNotEmpty ?? false)
                    ? NetworkImage(provider.logoUrl!)
                    : null,
                child: (provider.logoUrl?.isEmpty ?? true)
                    ? const Icon(Icons.business, color: Colors.white, size: 30)
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // Provider Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business Name
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.businessName,
                            style: AppTheme.heading3.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (provider.verified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha:0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.success),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Description
                    Text(
                      provider.description,
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Rating and Distance
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
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Services count and website
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${provider.services.length} service${provider.services.length != 1 ? 's' : ''}',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (provider.websiteUrl?.isNotEmpty ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.accent),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language,
                                  size: 12,
                                  color: AppTheme.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Website',
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
}
