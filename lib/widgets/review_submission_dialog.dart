import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';
import '../models/provider.dart' as app_provider;
import '../services/comprehensive_review_service.dart';
import 'review_rating_stars.dart';
import '../utils/app_logger.dart';

class ReviewSubmissionDialog extends StatefulWidget {
  final Booking booking;
  final app_provider.Provider provider;
  final VoidCallback? onReviewSubmitted;

  const ReviewSubmissionDialog({
    super.key,
    required this.booking,
    required this.provider,
    this.onReviewSubmitted,
  });

  @override
  State<ReviewSubmissionDialog> createState() => _ReviewSubmissionDialogState();
}

class _ReviewSubmissionDialogState extends State<ReviewSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: AppTheme.warning,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate Your Experience',
                            style: AppTheme.heading3.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'How was your service with ${widget.provider.businessName}?',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Rating input
                ReviewRatingInput(
                  initialRating: _rating,
                  label: 'Rating',
                  onRatingChanged: (rating) {
                    setState(() {
                      _rating = rating;
                    });
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Comment input
                TextFormField(
                  controller: _commentController,
                  maxLines: 4,
                  maxLength: 250,
                  decoration: InputDecoration(
                    labelText: 'Your Review (Optional)',
                    hintText: 'Tell others about your experience...',
                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.textTertiary.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.textTertiary.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryPurple),
                    ),
                    filled: true,
                    fillColor: AppTheme.cardDark,
                    counterStyle: TextStyle(color: AppTheme.textTertiary),
                  ),
                  style: TextStyle(color: AppTheme.textPrimary),
                  validator: (value) {
                    if (value != null && value.trim().length > 250) {
                      return 'Review must be 250 characters or less';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Service details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textTertiary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Details',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.booking.serviceTitle,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed on ${_formatDate(widget.booking.completedAt ?? widget.booking.updatedAt)}',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.textTertiary.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        style: AppTheme.primaryButtonStyle.copyWith(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(vertical: 16),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Submit Review',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],  // Close children array
            ),  // Close Column
          ),  // Close Form
        ),  // Close Padding
      ),  // Close SingleChildScrollView
    ),  // Close Container
    );  // Close Dialog
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ComprehensiveReviewService.createReview(
        bookingId: widget.booking.bookingId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review submitted successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        
        Navigator.of(context).pop();
        widget.onReviewSubmitted?.call();
      }
    } catch (e) {
      AppLogger.error('Error submitting review: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

