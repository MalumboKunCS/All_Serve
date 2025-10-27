import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/booking.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

class RateProviderScreen extends StatefulWidget {
  final Booking booking;

  const RateProviderScreen({
    super.key,
    required this.booking,
  });

  @override
  State<RateProviderScreen> createState() => _RateProviderScreenState();
}

class _RateProviderScreenState extends State<RateProviderScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _reviewController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Service quality aspects
  bool _punctuality = false;
  bool _professionalism = false;
  bool _quality = false;
  bool _wouldRecommend = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final reviewId = 'REV_${DateTime.now().millisecondsSinceEpoch}';

      // Create review document
      final customerName = widget.booking.customerFullName ?? 
          widget.booking.customerData?['name'] ?? 'Customer';
      
      await _firestore.collection('reviews').doc(reviewId).set({
        'reviewId': reviewId,
        'bookingId': widget.booking.bookingId,
        'providerId': widget.booking.providerId,
        'customerId': currentUser.uid,
        'customerName': customerName,
        'serviceId': widget.booking.serviceId,
        'serviceName': widget.booking.serviceTitle,
        'rating': _rating,
        'reviewText': _reviewController.text.trim(),
        'punctuality': _punctuality,
        'professionalism': _professionalism,
        'quality': _quality,
        'wouldRecommend': _wouldRecommend,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': true, // Verified because it's from a completed booking
      });

      // Update booking with review status
      await _firestore
          .collection('bookings')
          .doc(widget.booking.bookingId)
          .update({
        'reviewId': reviewId,
        'isReviewed': true,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Update provider's average rating
      await _updateProviderRating(widget.booking.providerId, _rating);

      // Create notification for provider
      await _createProviderNotification(reviewId);

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
      _animationController.forward();

      // Auto-navigate after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProviderRating(String providerId, int newRating) async {
    try {
      final providerDoc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();

      if (providerDoc.exists) {
        final data = providerDoc.data()!;
        final currentRating = (data['averageRating'] ?? 0.0) as double;
        final totalReviews = (data['totalReviews'] ?? 0) as int;

        // Calculate new average
        final newTotalReviews = totalReviews + 1;
        final newAverageRating =
            ((currentRating * totalReviews) + newRating) / newTotalReviews;

        await _firestore.collection('providers').doc(providerId).update({
          'averageRating': newAverageRating,
          'totalReviews': newTotalReviews,
        });
      }
    } catch (e) {
      debugPrint('Error updating provider rating: $e');
    }
  }

  Future<void> _createProviderNotification(String reviewId) async {
    try {
      final customerName = widget.booking.customerFullName ?? 
          widget.booking.customerData?['name'] ?? 'Customer';
      
      await _firestore.collection('notifications').add({
        'receiverId': widget.booking.providerId,
        'type': 'new_review',
        'title': 'New Review Received',
        'message':
            '$customerName rated your service ${_rating} star${_rating > 1 ? 's' : ''}',
        'bookingId': widget.booking.bookingId,
        'reviewId': reviewId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error creating notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return _buildSuccessView();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: AppTheme.textPrimary,
        ),
        title: const Text('Rate Your Experience'),
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildServiceInfoCard(),
              const SizedBox(height: 24),
              _buildRatingSection(),
              const SizedBox(height: 24),
              _buildQualityCheckboxes(),
              const SizedBox(height: 24),
              _buildReviewTextField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.1),
            AppTheme.accent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.cleaning_services,
                  color: AppTheme.primaryPurple,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.booking.serviceTitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Provided by ${widget.booking.providerData?['name'] ?? 'Provider'}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.cardLight),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                Icons.calendar_today,
                _formatDate(widget.booking.scheduledAt.toIso8601String()),
              ),
              _buildInfoItem(
                Icons.access_time,
                widget.booking.timeSlot ?? widget.booking.formattedScheduledTime,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(
        children: [
          Text(
            'How would you rate this service?',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starNumber),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    _rating >= starNumber ? Icons.star : Icons.star_border,
                    color: _rating >= starNumber
                        ? Colors.amber
                        : AppTheme.textSecondary,
                    size: 48,
                  ),
                ),
              );
            }),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 12),
            Text(
              _getRatingText(_rating),
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityCheckboxes() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Quality',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildCheckbox(
            'Punctual & On Time',
            _punctuality,
            (value) => setState(() => _punctuality = value ?? false),
            Icons.access_time_filled,
          ),
          _buildCheckbox(
            'Professional Service',
            _professionalism,
            (value) => setState(() => _professionalism = value ?? false),
            Icons.verified_user,
          ),
          _buildCheckbox(
            'High Quality Work',
            _quality,
            (value) => setState(() => _quality = value ?? false),
            Icons.high_quality,
          ),
          _buildCheckbox(
            'Would Recommend',
            _wouldRecommend,
            (value) => setState(() => _wouldRecommend = value ?? false),
            Icons.thumb_up,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: value ? AppTheme.primaryPurple : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: value ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: value ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.primaryPurple,
                checkColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewTextField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rate_review,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Write a Review (Optional)',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Share your experience with this service...',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.cardLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.cardLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRating,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryPurple,
          disabledBackgroundColor: AppTheme.primaryPurple.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Submit Review',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Thank You!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your review has been submitted successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Redirecting to home...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
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
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
