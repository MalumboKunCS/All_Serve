import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../widgets/contact_info_section.dart';
import '../../widgets/profile_image_widget.dart';
import '../../widgets/service_image_widget.dart';
import '../../widgets/review_card.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/app_logger.dart';
import '../../models/review.dart';
import '../../services/comprehensive_review_service.dart';
import 'booking_screen.dart';
import 'provider_reviews_screen.dart';

class ProviderDetailScreen extends StatefulWidget {
  final app_provider.Provider provider;

  const ProviderDetailScreen({
    super.key,
    required this.provider,
  });

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<app_provider.Service> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    // Load services from provider data
    setState(() {
      _services = widget.provider.services;
      _isLoading = false;
    });
  }

  Future<void> _visitWebsite() async {
    final websiteUrl = widget.provider.websiteUrl;
    if (websiteUrl == null || websiteUrl.isEmpty) return;

    try {
      final uri = Uri.parse(websiteUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open website: $websiteUrl'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open website: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // App Bar with Provider Info
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.surfaceDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Provider Images
                  ProviderGalleryWidget(
                    images: widget.provider.images,
                    galleryImages: widget.provider.galleryImages,
                    height: 300,
                  ),
                  
                  // Gradient Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha:0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Provider Info
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BusinessImageWidget(
                              imageUrl: widget.provider.logoUrl,
                              businessName: widget.provider.businessName,
                              radius: 30,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.provider.businessName,
                                    style: AppTheme.heading1.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                        '${widget.provider.ratingAvg.toStringAsFixed(1)} (${widget.provider.ratingCount} reviews)',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Show cancellation rate if provider has accepted bookings
                                  if (widget.provider.acceptedCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: widget.provider.hasHighCancellationRate 
                                              ? AppTheme.warning 
                                              : AppTheme.success,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Cancellation rate: ${widget.provider.cancellationRate.toStringAsFixed(1)}%',
                                          style: AppTheme.caption.copyWith(
                                            color: widget.provider.hasHighCancellationRate 
                                                ? AppTheme.warning 
                                                : Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            // Remove share button (Issue 9: Remove share button from provider detail screen)
            actions: [],
          ),
          
          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryPurple,
                unselectedLabelColor: AppTheme.textTertiary,
                indicatorColor: AppTheme.primaryPurple,
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Services'),
                  Tab(text: 'Reviews'),
                ],
              ),
            ),
          ),
          
          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // About Tab
                _buildAboutTab(),
                
                // Services Tab
                _buildServicesTab(),
                
                // Reviews Tab
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
      
      // Action Buttons
      bottomNavigationBar: Container(
        padding: ResponsiveUtils.getResponsivePadding(context),
        color: AppTheme.surfaceDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reviews summary bar
            if (widget.provider.ratingCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.cardDark),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.provider.ratingAvg.toStringAsFixed(1)} (${widget.provider.ratingCount} reviews)',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        _tabController.animateTo(2); // Navigate to reviews tab
                      },
                      child: Text(
                        'View All',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action buttons
            widget.provider.websiteUrl?.isNotEmpty ?? false
              ? Row(
                  children: [
                    // Visit Website Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _visitWebsite,
                        style: AppTheme.outlineButtonStyle,
                        icon: Icon(
                          Icons.language,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 18,
                            tablet: 20,
                            desktop: 22,
                          ),
                        ),
                        label: Text(
                          'Visit Website',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 12,
                              tablet: 14,
                              desktop: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    )),
                    // Book Service Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          try {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BookingScreen(provider: widget.provider),
                              ),
                            );
                          } catch (e) {
                            AppLogger.error('Error navigating to booking: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to open booking'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        style: AppTheme.primaryButtonStyle,
                        icon: Icon(
                          Icons.calendar_today,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 18,
                            tablet: 20,
                            desktop: 22,
                          ),
                        ),
                        label: Text(
                          'Book Service',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 12,
                              tablet: 14,
                              desktop: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ElevatedButton.icon(
                  onPressed: () {
                    try {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(provider: widget.provider),
                        ),
                      );
                    } catch (e) {
                      AppLogger.error('Error navigating to booking: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unable to open booking'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  },
                  style: AppTheme.primaryButtonStyle,
                  icon: Icon(
                    Icons.calendar_today,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                  ),
                  label: Text(
                    'Book Service',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 14,
                        desktop: 16,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: AppTheme.heading2.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.provider.description,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Contact Information
          Text(
            'Contact Information',
            style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          if (widget.provider.websiteUrl != null) ...[
            ListTile(
              leading: Icon(Icons.language, color: AppTheme.accentBlue),
              title: Text(
                'Website',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                widget.provider.websiteUrl!,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.accentBlue,
                ),
              ),
              onTap: () {
                // TODO: Open website
              },
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Service Area
          Text(
            'Service Area',
            style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppTheme.info,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Radius',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${widget.provider.serviceAreaKm} km',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _services.isEmpty
            ? _buildEmptyServicesState()
            : ListView.builder(
                padding: ResponsiveUtils.getResponsivePadding(context),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return _buildServiceCard(service);
                },
              );
  }

  Widget _buildServiceCard(app_provider.Service service) {
    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 16,
          tablet: 18,
          desktop: 20,
        ),
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Image
                ServiceImageWidget(
                  imageUrls: service.imageUrls,
                  imageUrl: service.imageUrl,
                  width: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 80,
                    tablet: 90,
                    desktop: 100,
                  ),
                  height: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 80,
                    tablet: 90,
                    desktop: 100,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                )),
                // Service Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Title and Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              service.title,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12,
                          )),
                          // Service Type Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                mobile: 8,
                                tablet: 10,
                                desktop: 12,
                              ),
                              vertical: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                mobile: 4,
                                tablet: 6,
                                desktop: 8,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: service.serviceType == 'bookable' 
                                  ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                                  : AppTheme.accentBlue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              service.serviceType == 'bookable' ? 'BOOKABLE' : 'CONTACT',
                              style: AppTheme.caption.copyWith(
                                color: service.serviceType == 'bookable' 
                                    ? AppTheme.primaryPurple
                                    : AppTheme.accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 10,
                                  tablet: 11,
                                  desktop: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      )),
                      // Duration
                      Text(
                        'Duration: ${service.duration ?? 'Not specified'}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 15,
                            desktop: 16,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 4,
                        tablet: 6,
                        desktop: 8,
                      )),
                      // Price Information
                      _buildPriceInfo(service),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            )),
            // Action Button
            SizedBox(
              width: double.infinity,
              child: service.serviceType == 'bookable'
                  ? ElevatedButton(
                      onPressed: () {
                        try {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(
                                provider: widget.provider,
                                selectedService: service,
                              ),
                            ),
                          );
                        } catch (e) {
                          AppLogger.error('Error navigating to booking: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unable to open booking'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 20,
                            tablet: 24,
                            desktop: 28,
                          ),
                          vertical: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 12,
                            tablet: 14,
                            desktop: 16,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Book',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18,
                          ),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        _showContactInfoDialog(context, service);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 20,
                            tablet: 24,
                            desktop: 28,
                          ),
                          vertical: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 12,
                            tablet: 14,
                            desktop: 16,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Contact',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInfo(app_provider.Service service) {
    if (service.type == 'priced' && service.priceFrom != null && service.priceTo != null) {
      return Text(
        'Price: K${service.priceFrom!.toStringAsFixed(0)} - K${service.priceTo!.toStringAsFixed(0)}',
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.accentPurple,
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.getResponsiveFontSize(
            context,
            mobile: 14,
            tablet: 15,
            desktop: 16,
          ),
        ),
      );
    } else if (service.type == 'negotiable') {
      return Text(
        'Price: Negotiable',
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.warning,
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.getResponsiveFontSize(
            context,
            mobile: 14,
            tablet: 15,
            desktop: 16,
          ),
        ),
      );
    } else if (service.type == 'free') {
      return Text(
        'Price: Free',
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.success,
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.getResponsiveFontSize(
            context,
            mobile: 14,
            tablet: 15,
            desktop: 16,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEmptyServicesState() {
    return Center(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: ResponsiveUtils.getResponsiveIconSize(
                context,
                mobile: 80,
                tablet: 90,
                desktop: 100,
              ),
              color: AppTheme.textTertiary,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            )),
            Text(
              'No Services Available',
              style: AppTheme.heading3.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            )),
            Text(
              'This provider hasn\'t added any services yet.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getProviderStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: AppTheme.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load reviews',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final stats = snapshot.data ?? {};
        
        return StreamBuilder<List<Review>>(
          stream: ComprehensiveReviewService.getProviderReviews(widget.provider.providerId),
          builder: (context, reviewsSnapshot) {
            if (reviewsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (reviewsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading reviews: ${reviewsSnapshot.error}',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                ),
              );
            }

            final reviews = reviewsSnapshot.data ?? <Review>[];
            
            if (reviews.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border, color: AppTheme.textSecondary, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'No Reviews Yet',
                      style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to review this provider',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: ResponsiveUtils.getResponsivePadding(context),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return ReviewCard(review: review);
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getProviderStats() async {
    try {
      return await ComprehensiveReviewService.getProviderStats(widget.provider.providerId);
    } catch (e) {
      AppLogger.error('Error loading provider stats: $e');
      return {};
    }
  }

  void _showContactInfoDialog(BuildContext context, app_provider.Service service) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.contact_phone, color: AppTheme.primaryPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Provider',
                            style: AppTheme.heading3.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            service.title,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Contact Info
              Flexible(
                child: SingleChildScrollView(
                  child: ContactInfoSection(service: service),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: AppTheme.surfaceDark,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

