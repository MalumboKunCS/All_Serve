import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import '../models/booking.dart';
import '../utils/app_logger.dart';
import 'booking_validation_service.dart';
import 'notification_service.dart';

/// Service for atomic review operations using Firestore transactions
/// This ensures provider ratings are updated atomically with review creation
class AtomicReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a review atomically and updates provider rating in the same transaction
  /// 
  /// This method ensures atomicity by:
  /// 1. Validating review eligibility (completed booking, within 30 days, not already reviewed)
  /// 2. Creating the review document
  /// 3. Updating provider's rating atomically
  /// 4. Marking booking as reviewed
  /// 
  /// Returns review ID on success, throws exception on failure
  static Future<String> createReviewAtomic({
    required String bookingId,
    required String reviewerId,
    required String providerId,
    required double rating,
    required String body,
    String? title,
    List<String>? tags,
    List<String>? images,
  }) async {
    try {
      AppLogger.info(
        'Starting atomic review creation: '
        'booking=$bookingId, reviewer=$reviewerId, rating=$rating'
      );

      // Step 1: Pre-transaction validation
      final booking = await _getAndValidateBooking(bookingId, reviewerId);

      // Validate review data
      final validationResult = BookingValidationService.validateReviewData(
        rating: rating,
        comment: body,
      );

      if (!validationResult.isValid) {
        throw ReviewValidationException(validationResult.errorMessage);
      }

      // Validate review eligibility
      final eligibilityResult = BookingValidationService.validateReviewEligibility(
        booking: booking,
        customerId: reviewerId,
      );

      if (!eligibilityResult.isValid) {
        throw ReviewEligibilityException(eligibilityResult.errorMessage);
      }

      // Step 2: Execute transaction
      final reviewId = await _firestore.runTransaction<String>(
        (transaction) async {
          // 2a. Double-check booking hasn't been reviewed in another transaction
          final bookingRef = _firestore.collection('bookings').doc(bookingId);
          final bookingDoc = await transaction.get(bookingRef);
          
          if (!bookingDoc.exists) {
            throw BookingNotFoundException('Booking not found: $bookingId');
          }

          final bookingData = bookingDoc.data()!;
          if (bookingData['hasReview'] == true) {
            throw ReviewAlreadyExistsException(
              'This booking has already been reviewed'
            );
          }

          // 2b. Check for duplicate review by query ID (outside transaction, verify in transaction)
          final existingReviews = await _firestore
              .collection('reviews')
              .where('bookingId', isEqualTo: bookingId)
              .where('reviewerId', isEqualTo: reviewerId)
              .limit(1)
              .get();

          if (existingReviews.docs.isNotEmpty) {
            throw ReviewAlreadyExistsException(
              'You have already reviewed this booking'
            );
          }

          // 2c. Create review document
          final reviewRef = _firestore.collection('reviews').doc();
          final now = DateTime.now();

          final reviewData = {
            'bookingId': bookingId,
            'reviewerId': reviewerId,
            'providerId': providerId,
            'rating': rating,
            'title': title,
            'body': body,
            'tags': tags ?? [],
            'images': images ?? [],
            'isVisible': true,
            'isVerified': false,
            'isFlagged': false,
            'helpfulCount': 0,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          };

          transaction.set(reviewRef, reviewData);

          // 2d. Update provider rating atomically
          await _updateProviderRatingInTransaction(
            transaction: transaction,
            providerId: providerId,
            newRating: rating,
          );

          // 2e. Mark booking as reviewed
          transaction.update(bookingRef, {
            'hasReview': true,
            'reviewId': reviewRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          AppLogger.info('Review created atomically: ${reviewRef.id}');
          return reviewRef.id;
        },
        timeout: const Duration(seconds: 10),
      );

      // Step 3: Post-transaction operations (notifications)
      await _postReviewCreation(
        reviewId: reviewId,
        bookingId: bookingId,
        reviewerId: reviewerId,
        providerId: providerId,
        rating: rating,
      );

      return reviewId;
    } on ReviewException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to create atomic review: $e', stackTrace);
      throw ReviewCreationException(
        'Failed to create review. Please try again. Error: ${e.toString()}'
      );
    }
  }

  /// Updates a review atomically and recalculates provider rating
  static Future<void> updateReviewAtomic({
    required String reviewId,
    required String reviewerId,
    double? rating,
    String? title,
    String? body,
    List<String>? tags,
    List<String>? images,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get current review
        final reviewRef = _firestore.collection('reviews').doc(reviewId);
        final reviewDoc = await transaction.get(reviewRef);

        if (!reviewDoc.exists) {
          throw ReviewNotFoundException('Review not found: $reviewId');
        }

        final currentReview = Review.fromFirestore(reviewDoc);

        // Verify ownership
        if (currentReview.customerId != reviewerId) {
          throw UnauthorizedReviewException(
            'You do not have permission to update this review'
          );
        }

        // Check if review can be edited (within 7 days)
        final reviewAge = DateTime.now().difference(currentReview.createdAt);
        if (reviewAge.inDays > 7) {
          throw ReviewEditExpiredException(
            'Reviews can only be edited within 7 days of creation'
          );
        }

        // Prepare update data
        final updateData = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (title != null) updateData['title'] = title;
        if (body != null) {
          // Validate body
          final validation = BookingValidationService.validateReviewData(
            rating: rating ?? currentReview.rating,
            comment: body,
          );
          if (!validation.isValid) {
            throw ReviewValidationException(validation.errorMessage);
          }
          updateData['body'] = body;
        }
        if (tags != null) updateData['tags'] = tags;
        if (images != null) updateData['images'] = images;

        bool ratingChanged = false;
        if (rating != null && rating != currentReview.rating) {
          // Validate rating
          if (rating < 1 || rating > 5) {
            throw ReviewValidationException('Rating must be between 1 and 5');
          }
          updateData['rating'] = rating;
          ratingChanged = true;
        }

        // Update review
        transaction.update(reviewRef, updateData);

        // Recalculate provider rating if rating changed
        if (ratingChanged) {
          await _recalculateProviderRatingInTransaction(
            transaction: transaction,
            providerId: currentReview.providerId,
          );
        }

        AppLogger.info('Review updated atomically: $reviewId');
      });
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to update review atomically: $e', stackTrace);
      rethrow;
    }
  }

  /// Deletes a review atomically and recalculates provider rating
  static Future<void> deleteReviewAtomic({
    required String reviewId,
    required String reviewerId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reviewRef = _firestore.collection('reviews').doc(reviewId);
        final reviewDoc = await transaction.get(reviewRef);

        if (!reviewDoc.exists) {
          throw ReviewNotFoundException('Review not found: $reviewId');
        }

        final review = Review.fromFirestore(reviewDoc);

        // Verify ownership
        if (review.customerId != reviewerId) {
          throw UnauthorizedReviewException(
            'You do not have permission to delete this review'
          );
        }

        // Check if review can be deleted (within 7 days)
        final reviewAge = DateTime.now().difference(review.createdAt);
        if (reviewAge.inDays > 7) {
          throw ReviewDeleteExpiredException(
            'Reviews can only be deleted within 7 days of creation'
          );
        }

        // Delete review
        transaction.delete(reviewRef);

        // Recalculate provider rating
        await _recalculateProviderRatingInTransaction(
          transaction: transaction,
          providerId: review.providerId,
        );

        // Update booking
        if (review.bookingId != null) {
          final bookingRef = _firestore.collection('bookings').doc(review.bookingId);
          transaction.update(bookingRef, {
            'hasReview': false,
            'reviewId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        AppLogger.info('Review deleted atomically: $reviewId');
      });
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to delete review atomically: $e', stackTrace);
      rethrow;
    }
  }

  /// Flags a review for admin moderation (maintains atomic rating)
  static Future<void> flagReviewAtomic({
    required String reviewId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final reviewRef = _firestore.collection('reviews').doc(reviewId);
        final reviewDoc = await transaction.get(reviewRef);

        if (!reviewDoc.exists) {
          throw ReviewNotFoundException('Review not found: $reviewId');
        }

        final review = Review.fromFirestore(reviewDoc);

        // Create report document
        final reportRef = _firestore.collection('review_reports').doc();
        transaction.set(reportRef, {
          'reviewId': reviewId,
          'reporterId': reporterId,
          'reason': reason,
          'details': details,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        // Flag review if threshold reached (e.g., 3+ reports)
        // For now, immediately flag for admin review
        transaction.update(reviewRef, {
          'isFlagged': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger.info('Review flagged for moderation: $reviewId');
      });
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to flag review: $e', stackTrace);
      rethrow;
    }
  }

  // Private helper methods

  static Future<Booking> _getAndValidateBooking(
    String bookingId,
    String reviewerId,
  ) async {
    final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();

    if (!bookingDoc.exists) {
      throw BookingNotFoundException('Booking not found: $bookingId');
    }

    final booking = Booking.fromFirestore(bookingDoc);

    // Verify reviewer is the customer
    if (booking.customerId != reviewerId) {
      throw UnauthorizedReviewException(
        'Only the customer who booked the service can leave a review'
      );
    }

    return booking;
  }

  static Future<void> _updateProviderRatingInTransaction({
    required Transaction transaction,
    required String providerId,
    required double newRating,
  }) async {
    // Query all reviews for provider (outside transaction)
    final reviewsSnapshot = await _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .where('isVisible', isEqualTo: true)
        .get();

    // Calculate new average including the new review
    double totalRating = newRating;
    int reviewCount = 1;

    for (final doc in reviewsSnapshot.docs) {
      final data = doc.data();
      totalRating += (data['rating'] as num?)?.toDouble() ?? 0.0;
      reviewCount++;
    }

    final averageRating = totalRating / reviewCount;

    // Update provider atomically
    final providerRef = _firestore.collection('providers').doc(providerId);
    transaction.update(providerRef, {
      'rating': averageRating,
      'reviewCount': reviewCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.info(
      'Provider rating updated: $providerId -> $averageRating ($reviewCount reviews)'
    );
  }

  static Future<void> _recalculateProviderRatingInTransaction({
    required Transaction transaction,
    required String providerId,
  }) async {
    // Query all visible reviews for provider
    final reviewsSnapshot = await _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .where('isVisible', isEqualTo: true)
        .get();

    double totalRating = 0.0;
    int reviewCount = 0;

    // Re-verify each review in transaction for consistency
    for (final doc in reviewsSnapshot.docs) {
      final transactionDoc = await transaction.get(doc.reference);
      if (transactionDoc.exists) {
        final data = transactionDoc.data() as Map<String, dynamic>;
        if (data['isVisible'] == true) {
          totalRating += (data['rating'] as num?)?.toDouble() ?? 0.0;
          reviewCount++;
        }
      }
    }

    final averageRating = reviewCount > 0 ? totalRating / reviewCount : 0.0;

    // Update provider atomically
    final providerRef = _firestore.collection('providers').doc(providerId);
    transaction.update(providerRef, {
      'rating': averageRating,
      'reviewCount': reviewCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.info(
      'Provider rating recalculated: $providerId -> $averageRating ($reviewCount reviews)'
    );
  }

  static Future<void> _postReviewCreation({
    required String reviewId,
    required String bookingId,
    required String reviewerId,
    required String providerId,
    required double rating,
  }) async {
    try {
      // Send notification to provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'New Review Received',
        body: 'You received a ${rating.toStringAsFixed(1)}-star review',
        data: {
          'type': 'new_review',
          'reviewId': reviewId,
          'bookingId': bookingId,
        },
      );
    } catch (e) {
      AppLogger.warning('Failed to send review notification: $e');
      // Don't throw - notifications are not critical
    }
  }
}

// Custom exceptions for better error handling

class ReviewException implements Exception {
  final String message;
  ReviewException(this.message);

  @override
  String toString() => 'ReviewException: $message';
}

class ReviewValidationException extends ReviewException {
  ReviewValidationException(super.message);
}

class ReviewEligibilityException extends ReviewException {
  ReviewEligibilityException(super.message);
}

class ReviewAlreadyExistsException extends ReviewException {
  ReviewAlreadyExistsException(super.message);
}

class ReviewNotFoundException extends ReviewException {
  ReviewNotFoundException(super.message);
}

class ReviewCreationException extends ReviewException {
  ReviewCreationException(super.message);
}

class UnauthorizedReviewException extends ReviewException {
  UnauthorizedReviewException(super.message);
}

class ReviewEditExpiredException extends ReviewException {
  ReviewEditExpiredException(super.message);
}

class ReviewDeleteExpiredException extends ReviewException {
  ReviewDeleteExpiredException(super.message);
}

class BookingNotFoundException extends ReviewException {
  BookingNotFoundException(super.message);
}
