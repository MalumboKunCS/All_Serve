import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/review.dart';
import '../../models/user.dart' as app_user;

class ProviderReviewsScreen extends StatefulWidget {
  final app_provider.Provider? provider;

  const ProviderReviewsScreen({
    super.key,
    this.provider,
  });

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalReviews = 0;
  Map<int, int> _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  @override
  void initState() {
    super.initState();
    _loadRatingStats();
  }

  Future<void> _loadRatingStats() async {
    if (widget.provider == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final reviewsQuery = await FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: widget.provider!.providerId)
          .get();

      double totalRating = 0.0;
      Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (var doc in reviewsQuery.docs) {
        final review = Review.fromFirestore(doc);
        totalRating += review.rating;
        distribution[review.rating.round()] = (distribution[review.rating.round()] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _totalReviews = reviewsQuery.docs.length;
          _averageRating = _totalReviews > 0 ? totalRating / _totalReviews : 0.0;
          _ratingDistribution = distribution;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading rating stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provider == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('Reviews'),
          backgroundColor: AppTheme.surfaceDark,
        ),
        body: const Center(
          child: Text(
            'No provider data available',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Reviews & Ratings'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: Column(
        children: [
          // Rating Summary
          _buildRatingSummary(),
          
          // Reviews List
          Expanded(
            child: _buildReviewsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Average Rating Display
                Column(
                  children: [
                    Text(
                      _averageRating.toStringAsFixed(1),
                      style: AppTheme.heading1.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildStarRating(_averageRating),
                    const SizedBox(height: 8),
                    Text(
                      '$_totalReviews review${_totalReviews != 1 ? 's' : ''}',
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 32),
                
                // Rating Distribution
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 5; i >= 1; i--)
                        _buildRatingBar(i, _ratingDistribution[i] ?? 0),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    List<Widget> stars = [];
    
    for (int i = 1; i <= 5; i++) {
      stars.add(Icon(
        Icons.star,
        color: i <= rating ? AppTheme.warning : AppTheme.textTertiary,
        size: 20,
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars,
    );
  }

  Widget _buildRatingBar(int stars, int count) {
    final percentage = _totalReviews > 0 ? count / _totalReviews : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$stars',
            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.star,
            size: 12,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.warning,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: widget.provider!.providerId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          );
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
                  style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                ),
              ],
            ),
          );
        }

        final reviews = snapshot.data?.docs ?? [];

        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No reviews yet',
                  style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reviews from customers will appear here',
                  style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final reviewDoc = reviews[index];
            final review = Review.fromFirestore(reviewDoc);
            return _buildReviewCard(review);
          },
        );
      },
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer info and rating
            Row(
              children: [
                // Customer avatar and name
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(review.customerId)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final customer = app_user.User.fromFirestore(snapshot.data!);
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primary,
                            backgroundImage: (customer.profileImageUrl?.isNotEmpty ?? false)
                                ? NetworkImage(customer.profileImageUrl!)
                                : null,
                            child: (customer.profileImageUrl?.isEmpty ?? true)
                                ? const Icon(Icons.person, color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: AppTheme.bodyText.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDateTime(review.createdAt),
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primary,
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppTheme.textTertiary.withValues(alpha:0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 60,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.textTertiary.withValues(alpha:0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                
                const Spacer(),
                
                // Star rating
                _buildStarRating(review.rating.toDouble()),
              ],
            ),

            const SizedBox(height: 12),

            // Review comment
            if (review.comment.isNotEmpty)
              Text(
                review.comment,
                style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
              ),

            // Flagged indicator
            if (review.flagged) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withValues(alpha:0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag,
                      size: 14,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'FLAGGED: ${review.flagReason ?? 'No reason provided'}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
