import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;

import 'booking_screen.dart';

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
                  if (widget.provider.images.isNotEmpty)
                    PageView.builder(
                      itemCount: widget.provider.images.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.provider.images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    )
                  else
                    Container(
                      color: AppTheme.cardDark,
                      child: Icon(
                        Icons.image,
                        size: 100,
                        color: AppTheme.textTertiary,
                      ),
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
                            Colors.black.withOpacity(0.7),
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
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: widget.provider.logoUrl != null
                                  ? (widget.provider.logoUrl != null && widget.provider.logoUrl!.isNotEmpty)
                                    ? NetworkImage(widget.provider.logoUrl!)
                                    : null
                                  : null,
                              child: widget.provider.logoUrl == null
                                  ? Icon(
                                      Icons.business,
                                      size: 30,
                                      color: AppTheme.primaryPurple,
                                    )
                                  : null,
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
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Implement share functionality
                },
              ),
            ],
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
        padding: const EdgeInsets.all(16),
        color: AppTheme.surfaceDark,
        child: widget.provider.websiteUrl?.isNotEmpty ?? false
          ? Row(
              children: [
                // Visit Website Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _visitWebsite,
                    style: AppTheme.outlineButtonStyle,
                    icon: const Icon(Icons.language),
                    label: const Text('Visit Website'),
                  ),
                ),
                const SizedBox(width: 12),
                // Book Service Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(provider: widget.provider),
                        ),
                      );
                    },
                    style: AppTheme.primaryButtonStyle,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Book Service'),
                  ),
                ),
              ],
            )
          : ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookingScreen(provider: widget.provider),
                  ),
                );
              },
              style: AppTheme.primaryButtonStyle,
              icon: const Icon(Icons.calendar_today),
              label: const Text('Book Service'),
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
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _services.length,
            itemBuilder: (context, index) {
              final service = _services[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppTheme.cardDark,
                child: ListTile(
                  title: Text(
                    service.title,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duration: ${service.durationMin} minutes',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Price: K${service.priceFrom} - K${service.priceTo}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.accentPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(
                            provider: widget.provider,
                            selectedService: service,
                          ),
                        ),
                      );
                    },
                    style: AppTheme.secondaryButtonStyle,
                    child: const Text('Book'),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildReviewsTab() {
    return const Center(
      child: Text(
        'Reviews coming soon...',
        style: TextStyle(color: Colors.grey),
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

