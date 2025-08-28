import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/review.dart';
import '../../models/user.dart' as app_user;
import '../../models/provider.dart' as app_provider;

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  String _filterStatus = 'flagged';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Review Moderation',
                style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _filterStatus,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Reviews')),
                  DropdownMenuItem(value: 'flagged', child: Text('Flagged Only')),
                  DropdownMenuItem(value: 'unflagged', child: Text('Normal Reviews')),
                ],
                onChanged: (value) {
                  setState(() => _filterStatus = value ?? 'flagged');
                },
              ),
            ],
          ),
        ),

        // Reviews List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.error),
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
                        _filterStatus == 'flagged' 
                          ? Icons.flag_outlined 
                          : Icons.rate_review_outlined,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filterStatus == 'flagged' 
                          ? 'No flagged reviews'
                          : 'No reviews found',
                        style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _filterStatus == 'flagged'
                          ? 'Flagged reviews will appear here for moderation'
                          : 'Reviews will appear here',
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
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
          ),
        ),
      ],
    );
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('reviews');

    switch (_filterStatus) {
      case 'flagged':
        query = query.where('flagged', isEqualTo: true);
        break;
      case 'unflagged':
        query = query.where('flagged', isEqualTo: false);
        break;
      // 'all' doesn't need additional filtering
    }

    return query.orderBy('createdAt', descending: true);
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
            // Header with rating and flag status
            Row(
              children: [
                _buildStarRating(review.rating.round()),
                const Spacer(),
                if (review.flagged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, size: 14, color: AppTheme.error),
                        const SizedBox(width: 4),
                        Text(
                          'FLAGGED',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Review content
            if (review.comment.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  review.comment,
                  style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary),
                ),
              ),

            const SizedBox(height: 12),

            // Customer Info
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(review.customerId)
                  .get(),
              builder: (context, customerSnapshot) {
                if (customerSnapshot.hasData && customerSnapshot.data!.exists) {
                  final customer = app_user.User.fromFirestore(customerSnapshot.data!);
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary,
                        backgroundImage: (customer.profileImageUrl?.isNotEmpty ?? false)
                            ? NetworkImage(customer.profileImageUrl!)
                            : null,
                        child: (customer.profileImageUrl?.isEmpty ?? true)
                            ? const Icon(Icons.person, color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: AppTheme.caption.copyWith(
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
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 8),

            // Provider Info
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('providers')
                  .doc(review.providerId)
                  .get(),
              builder: (context, providerSnapshot) {
                if (providerSnapshot.hasData && providerSnapshot.data!.exists) {
                  final provider = app_provider.Provider.fromFirestore(providerSnapshot.data!);
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Provider: ${provider.businessName}',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Flag reason (if flagged)
            if (review.flagged && (review.flagReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flag Reason:',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.flagReason!,
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(review),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          Icons.star,
          size: 16,
          color: index < rating ? AppTheme.warning : AppTheme.textTertiary,
        );
      }),
    );
  }

  Widget _buildActionButtons(Review review) {
    if (review.flagged) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _removeReview(review),
              style: AppTheme.outlineButtonStyle.copyWith(
                foregroundColor: MaterialStateProperty.all(AppTheme.error),
                side: MaterialStateProperty.all(BorderSide(color: AppTheme.error)),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove Review'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approveReview(review),
              style: AppTheme.primaryButtonStyle,
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          const Spacer(),
          TextButton.icon(
            onPressed: () => _flagReview(review),
            icon: const Icon(Icons.flag),
            label: const Text('Flag Review'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
          ),
        ],
      );
    }
  }

  Future<void> _approveReview(Review review) async {
    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(review.reviewId)
          .update({
        'flagged': false,
        'flagReason': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review approved and unflagged'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve review: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeReview(Review review) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Remove Review',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to permanently remove this review? This action cannot be undone.',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove the review
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(review.reviewId)
          .delete();

      // Update provider rating (recalculate)
      // TODO: Implement rating recalculation Cloud Function

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review removed successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove review: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _flagReview(Review review) async {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Flag Review',
          style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for flagging this review:',
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: AppTheme.inputDecoration.copyWith(
                labelText: 'Flag Reason',
                hintText: 'e.g., Inappropriate content, fake review...',
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performFlagReview(review, reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            child: const Text('Flag'),
          ),
        ],
      ),
    );
  }

  Future<void> _performFlagReview(Review review, String reason) async {
    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please provide a flag reason'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(review.reviewId)
          .update({
        'flagged': true,
        'flagReason': reason.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review flagged for moderation'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to flag review: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
