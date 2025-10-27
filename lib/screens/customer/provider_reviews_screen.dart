import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/review.dart';
import '../../services/comprehensive_review_service.dart';
import '../../widgets/review_card.dart';
import '../../utils/app_logger.dart';
import '../../utils/responsive_utils.dart';

class CustomerProviderReviewsScreen extends StatefulWidget {
  final app_provider.Provider provider;

  const CustomerProviderReviewsScreen({
    super.key,
    required this.provider,
  });

  @override
  State<CustomerProviderReviewsScreen> createState() => _CustomerProviderReviewsScreenState();
}

class _CustomerProviderReviewsScreenState extends State<CustomerProviderReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ComprehensiveReviewService.getProviderStats(widget.provider.providerId);
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      AppLogger.error('Error loading provider stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('${widget.provider.businessName} Reviews'),
        backgroundColor: AppTheme.surfaceDark,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'All Reviews'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildReviewsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider info card
          Card(
            color: AppTheme.surfaceDark,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    backgroundImage: widget.provider.logoUrl != null
                        ? NetworkImage(widget.provider.logoUrl!)
                        : null,
                    child: widget.provider.logoUrl == null
                        ? Icon(
                            Icons.business,
                            color: AppTheme.primaryPurple,
                            size: 30,
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
                          style: AppTheme.heading3.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.provider.verified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
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
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Stats card
          if (_stats.isNotEmpty) ...[
            ReviewStatsCard(
              averageRating: _stats['averageRating'] ?? 0.0,
              totalReviews: _stats['totalReviews'] ?? 0,
              ratingDistribution: Map<String, int>.from(_stats['ratingDistribution'] ?? {}),
            ),
            const SizedBox(height: 24),
          ],

          // Recent reviews preview
          Text(
            'Recent Reviews',
            style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<Review>>(
            stream: ComprehensiveReviewService.getProviderReviews(widget.provider.providerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading reviews: ${snapshot.error}',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                  ),
                );
              }

              final reviews = snapshot.data ?? [];
              
              if (reviews.isEmpty) {
                return _buildEmptyState();
              }

              // Show only first 3 reviews in overview
              final recentReviews = reviews.take(3).toList();

              return Column(
                children: recentReviews.map((review) {
                  return ReviewCard(
                    review: review,
                    onTap: () {
                      _tabController.animateTo(1);
                    },
                  );
                }).toList(),
              );
            },
          ),

          if ((_stats['totalReviews'] ?? 0) > 3) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _tabController.animateTo(1);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppTheme.primaryPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'View All ${_stats['totalReviews']} Reviews',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return StreamBuilder<List<Review>>(
      stream: ComprehensiveReviewService.getProviderReviews(widget.provider.providerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading reviews',
                  style: AppTheme.heading3.copyWith(color: AppTheme.error),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
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

        final reviews = snapshot.data ?? [];
        
        if (reviews.isEmpty) {
          return _buildEmptyState();
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_border,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Reviews Yet',
            style: AppTheme.heading3.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to review ${widget.provider.businessName}',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}