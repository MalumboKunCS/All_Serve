import 'package:flutter/material.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/models/review.dart';

class ProviderReviewsPage extends StatefulWidget {
  final Provider provider;

  const ProviderReviewsPage({super.key, required this.provider});

  @override
  State<ProviderReviewsPage> createState() => _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends State<ProviderReviewsPage> {
  final ReviewService _reviewService = ReviewService();
  Map<String, dynamic>? _ratingStats;

  @override
  void initState() {
    super.initState();
    _loadRatingStats();
  }

  Future<void> _loadRatingStats() async {
    final stats = await _reviewService.getProviderRatingStats(widget.provider.id);
    setState(() {
      _ratingStats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Reviews & Ratings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Row(
        children: [
          // Left side - Rating Overview
          Container(
            width: 350,
            padding: const EdgeInsets.all(24),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rating Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Overall Rating
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        (_ratingStats?['averageRating'] ?? 0.0).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Icon(
                            Icons.star,
                            color: index < ((_ratingStats?['averageRating'] ?? 0.0).round())
                                ? Colors.amber
                                : Colors.grey.shade300,
                            size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_ratingStats?['totalReviews'] ?? 0} reviews',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Rating Distribution
                const Text(
                  'Rating Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_ratingStats != null)
                  ..._buildRatingDistribution(),
              ],
            ),
          ),

          // Right side - Reviews List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Reviews',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<List<Review>>(
                      stream: _reviewService.getProviderReviews(widget.provider.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final reviews = snapshot.data ?? [];

                        if (reviews.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.star_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Reviews from customers will appear here',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue.shade100,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.blue.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Customer ${review.userId.substring(0, 8)}...',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  ...List.generate(5, (starIndex) {
                                                    return Icon(
                                                      Icons.star,
                                                      size: 16,
                                                      color: starIndex < review.rating
                                                          ? Colors.amber
                                                          : Colors.grey.shade300,
                                                    );
                                                  }),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${review.rating}/5',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatDate(review.createdAt),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (review.comment != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        review.comment!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                    if (review.images != null && review.images!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 60,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: review.images!.length,
                                          itemBuilder: (context, imgIndex) {
                                            return Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              width: 60,
                                              height: 60,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  review.images![imgIndex],
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRatingDistribution() {
    final distribution = _ratingStats!['ratingDistribution'] as List<int>;
    final totalReviews = _ratingStats!['totalReviews'] as int;

    return List.generate(5, (index) {
      final starCount = 5 - index;
      final count = distribution[4 - index];
      final percentage = totalReviews > 0 ? (count / totalReviews) : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text('$starCount'),
            const SizedBox(width: 4),
            Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}




