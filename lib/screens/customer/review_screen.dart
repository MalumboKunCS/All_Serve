import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/booking.dart';
import '../../models/provider.dart' as app_provider;
import '../../models/review.dart';
import 'package:shared/shared.dart' as shared;
import '../../services/review_service_client.dart';

class ReviewScreen extends StatefulWidget {
  final Booking booking;
  final app_provider.Provider provider;

  const ReviewScreen({
    super.key,
    required this.booking,
    required this.provider,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _isLoading = false;
  bool _hasExistingReview = false;
  Review? _existingReview;

  @override
  void initState() {
    super.initState();
    _checkExistingReview();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingReview() async {
    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) return;

      // Check if user has already reviewed this booking
      final reviewQuery = await FirebaseFirestore.instance
          .collection('reviews')
          .where('bookingId', isEqualTo: widget.booking.bookingId)
          .where('customerId', isEqualTo: currentUser.uid)
          .get();

      if (reviewQuery.docs.isNotEmpty && mounted) {
        final review = Review.fromFirestore(reviewQuery.docs.first);
        setState(() {
          _hasExistingReview = true;
          _existingReview = review;
          _rating = review.rating.round();
          _commentController.text = review.comment;
        });
      }
    } catch (e) {
      print('Error checking existing review: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(_hasExistingReview ? 'Update Review' : 'Leave Review'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Info Card
              Card(
                color: AppTheme.surfaceDark,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primary,
                        backgroundImage: (widget.provider.logoUrl?.isNotEmpty ?? false)
                            ? NetworkImage(widget.provider.logoUrl!)
                            : null,
                        child: (widget.provider.logoUrl?.isEmpty ?? true)
                            ? const Icon(Icons.business, color: Colors.white, size: 30)
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
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Booking completed on ${_formatDate(widget.booking.scheduledAt)}',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (widget.provider.verified)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.2),
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
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Rating Section
              Text(
                'How was your experience?',
                style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              
              Card(
                color: AppTheme.surfaceDark,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Rate your experience',
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() => _rating = index + 1);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.star,
                                size: 40,
                                color: index < _rating 
                                  ? AppTheme.warning 
                                  : AppTheme.textTertiary,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getRatingText(_rating),
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Comment Section
              Text(
                'Share your thoughts (optional)',
                style: AppTheme.heading3.copyWith(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _commentController,
                decoration: AppTheme.inputDecoration.copyWith(
                  labelText: 'Write your review',
                  hintText: 'Tell others about your experience...',
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 5,
                maxLength: 500,
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Review must be 500 characters or less';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReview,
                  style: AppTheme.primaryButtonStyle,
                  child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Submitting...'),
                        ],
                      )
                    : Text(_hasExistingReview ? 'Update Review' : 'Submit Review'),
                ),
              ),

              const SizedBox(height: 16),

              // Review Guidelines
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppTheme.info, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Review Guidelines',
                          style: AppTheme.bodyText.copyWith(
                            color: AppTheme.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Be honest and constructive in your feedback\n'
                      '• Focus on the service quality and professionalism\n'
                      '• Avoid personal attacks or inappropriate language\n'
                      '• Your review helps other customers make informed decisions',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textSecondary,
                      ),
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

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor - Very unsatisfied';
      case 2:
        return 'Fair - Below expectations';
      case 3:
        return 'Good - Met expectations';
      case 4:
        return 'Very Good - Exceeded expectations';
      case 5:
        return 'Excellent - Outstanding service';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<shared.AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create or update review using client service
      final reviewService = ReviewServiceClient();
      
      if (_hasExistingReview) {
        await reviewService.updateReview(
          reviewId: _existingReview!.reviewId,
          customerId: currentUser.uid,
          rating: _rating.toDouble(),
          comment: _commentController.text.trim(),
        );
      } else {
        await reviewService.createReview(
          bookingId: widget.booking.bookingId,
          customerId: currentUser.uid,
          providerId: widget.booking.providerId,
          rating: _rating.toDouble(),
          comment: _commentController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasExistingReview 
              ? 'Review updated successfully!' 
              : 'Thank you for your review!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
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
        setState(() => _isLoading = false);
      }
    }
  }
}

