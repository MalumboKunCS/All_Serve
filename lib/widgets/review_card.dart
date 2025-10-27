import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/review.dart';
import '../utils/responsive_utils.dart';
import 'review_rating_stars.dart';

class ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback? onTap;
  final bool showProviderInfo;
  final bool showBookingDetails;

  const ReviewCard({
    super.key,
    required this.review,
    this.onTap,
    this.showProviderInfo = false,
    this.showBookingDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceDark,
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with customer info and rating
              Row(
                children: [
                  // Customer avatar
                  CircleAvatar(
                    radius: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    backgroundImage: review.customerAvatar != null
                        ? NetworkImage(review.customerAvatar!)
                        : null,
                    child: review.customerAvatar == null
                        ? Icon(
                            Icons.person,
                            color: AppTheme.primaryPurple,
                            size: ResponsiveUtils.getResponsiveIconSize(
                              context,
                              mobile: 20,
                              tablet: 22,
                              desktop: 24,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    ),
                  ),
                  
                  // Customer name and date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.customerName ?? 'Anonymous',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 16,
                              tablet: 17,
                              desktop: 18,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(review.createdAt),
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textTertiary,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 12,
                              tablet: 13,
                              desktop: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Rating stars
                  ReviewRatingStars(
                    rating: review.rating,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
                  ),
                ],
              ),
              
              // Review comment
              if (review.comment.isNotEmpty) ...[
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  ),
                ),
                Text(
                  review.comment,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                  ),
                  maxLines: ResponsiveUtils.isMobile(context) ? 4 : null,
                  overflow: ResponsiveUtils.isMobile(context) ? TextOverflow.ellipsis : null,
                ),
              ],
              
              // Helpful votes section
              if (review.helpfulVotes.isNotEmpty) ...[
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 16,
                        tablet: 17,
                        desktop: 18,
                      ),
                      color: AppTheme.success,
                    ),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 4,
                        tablet: 5,
                        desktop: 6,
                      ),
                    ),
                    Text(
                      '${review.helpfulVotes.length} helpful',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              // Flagged indicator
              if (review.isFlagged) ...[
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 8,
                    tablet: 10,
                    desktop: 12,
                  ),
                ),
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
                      tablet: 5,
                      desktop: 6,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flag,
                        size: ResponsiveUtils.getResponsiveIconSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                        color: AppTheme.error,
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 4,
                          tablet: 5,
                          desktop: 6,
                        ),
                      ),
                      Text(
                        'Flagged',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class ReviewStatsCard extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final Map<String, int> ratingDistribution;

  const ReviewStatsCard({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceDark,
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall rating
            Row(
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: AppTheme.heading1.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 32,
                      tablet: 36,
                      desktop: 40,
                    ),
                  ),
                ),
                SizedBox(
                  width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 8,
                    tablet: 10,
                    desktop: 12,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReviewRatingStars(
                      rating: averageRating,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                    ),
                    Text(
                      '$totalReviews reviews',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 16,
                tablet: 18,
                desktop: 20,
              ),
            ),
            
            // Rating distribution
            ...ratingDistribution.entries.map((entry) {
              final rating = entry.key;
              final count = entry.value;
              final percentage = totalReviews > 0 ? (count / totalReviews) * 100 : 0.0;
              
              return Padding(
                padding: EdgeInsets.only(
                  bottom: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 8,
                    tablet: 10,
                    desktop: 12,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      rating,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      ),
                    ),
                    Icon(
                      Icons.star,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 16,
                        tablet: 17,
                        desktop: 18,
                      ),
                      color: AppTheme.warning,
                    ),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: AppTheme.cardDark,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
                        minHeight: 6,
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      ),
                    ),
                    Text(
                      '$count',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

