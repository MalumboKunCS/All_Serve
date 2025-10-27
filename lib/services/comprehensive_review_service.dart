import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review.dart';
import '../models/booking.dart';
import '../models/provider.dart' as app_provider;
import 'package:shared/shared.dart' as shared;
import '../utils/app_logger.dart';

class ComprehensiveReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new review for a completed booking
  static Future<String?> createReview({
    required String bookingId,
    required double rating,
    required String comment,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      // Validate rating
      if (rating < 1.0 || rating > 5.0) {
        throw Exception('Rating must be between 1 and 5');
      }

      // Get booking details
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data()!;
      final booking = Booking.fromMap(bookingData, id: bookingId);

      // Verify customer can review this booking
      if (booking.customerId != currentUser.uid) {
        throw Exception('You can only review your own bookings');
      }

      // Check if booking is completed
      if (booking.status != BookingStatus.completed) {
        throw Exception('You can only review completed bookings');
      }

      // Check if review already exists
      if (booking.hasReview) {
        throw Exception('You have already reviewed this booking');
      }

      // Get customer details for display
      final customerDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final customerData = customerDoc.data();
      final customerName = customerData?['name'] ?? 'Anonymous';
      final customerAvatar = customerData?['avatarUrl'];

      // Create review document
      final reviewRef = await _firestore.collection('reviews').add({
        'bookingId': bookingId,
        'customerId': currentUser.uid,
        'providerId': booking.providerId,
        'rating': rating,
        'comment': comment.trim(),
        'customerName': customerName,
        'customerAvatar': customerAvatar,
        'isFlagged': false,
        'flagReason': null,
        'helpfulVotes': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update booking to mark as reviewed
      await _firestore.collection('bookings').doc(bookingId).update({
        'hasReview': true,
        'reviewId': reviewRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update provider's average rating
      await _updateProviderRating(booking.providerId);

      // Send notification to provider
      await _sendReviewNotification(booking.providerId, rating, customerName);

      AppLogger.info('Review created successfully: ${reviewRef.id}');
      return reviewRef.id;
    } catch (e) {
      AppLogger.error('Error creating review: $e');
      rethrow;
    }
  }

  /// Update an existing review
  static Future<void> updateReview({
    required String reviewId,
    required double rating,
    required String comment,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      // Get existing review
      final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final reviewData = reviewDoc.data()!;
      final review = Review.fromMap(reviewData, id: reviewId);

      // Verify user owns this review
      if (review.customerId != currentUser.uid) {
        throw Exception('You can only update your own reviews');
      }

      final oldRating = review.rating;

      // Update review
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': rating,
        'comment': comment.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update provider rating if rating changed
      if (oldRating != rating) {
        await _updateProviderRating(review.providerId);
      }

      AppLogger.info('Review updated successfully: $reviewId');
    } catch (e) {
      AppLogger.error('Error updating review: $e');
      rethrow;
    }
  }

  /// Delete a review (only by customer or admin)
  static Future<void> deleteReview(String reviewId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      // Get review details
      final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final reviewData = reviewDoc.data()!;
      final review = Review.fromMap(reviewData, id: reviewId);

      // Check if user is admin or review owner
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      final isAdmin = userData?['role'] == 'admin' || userData?['role'] == 'super_admin';

      if (!isAdmin && review.customerId != currentUser.uid) {
        throw Exception('You can only delete your own reviews');
      }

      // Delete review document
      await _firestore.collection('reviews').doc(reviewId).delete();

      // Update booking to remove review flag
      await _firestore.collection('bookings').doc(review.bookingId).update({
        'hasReview': false,
        'reviewId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update provider rating
      await _updateProviderRating(review.providerId);

      AppLogger.info('Review deleted successfully: $reviewId');
    } catch (e) {
      AppLogger.error('Error deleting review: $e');
      rethrow;
    }
  }

  /// Flag a review for inappropriate content
  static Future<void> flagReview({
    required String reviewId,
    required String reason,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      // Check if user is admin
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      final isAdmin = userData?['role'] == 'admin' || userData?['role'] == 'super_admin';

      if (!isAdmin) {
        throw Exception('Only admins can flag reviews');
      }

      // Update review with flag
      await _firestore.collection('reviews').doc(reviewId).update({
        'isFlagged': true,
        'flagReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Review flagged successfully: $reviewId');
    } catch (e) {
      AppLogger.error('Error flagging review: $e');
      rethrow;
    }
  }

  /// Unflag a review
  static Future<void> unflagReview(String reviewId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      // Check if user is admin
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      final isAdmin = userData?['role'] == 'admin' || userData?['role'] == 'super_admin';

      if (!isAdmin) {
        throw Exception('Only admins can unflag reviews');
      }

      // Update review to remove flag
      await _firestore.collection('reviews').doc(reviewId).update({
        'isFlagged': false,
        'flagReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Review unflagged successfully: $reviewId');
    } catch (e) {
      AppLogger.error('Error unflagged review: $e');
      rethrow;
    }
  }

  /// Get reviews for a specific provider
  static Stream<List<Review>> getProviderReviews(String providerId) {
    return _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .where('isFlagged', isEqualTo: false) // Only show unflagged reviews
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }

  /// Get all reviews (for admin)
  static Stream<List<Review>> getAllReviews() {
    return _firestore
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }

  /// Get flagged reviews (for admin)
  static Stream<List<Review>> getFlaggedReviews() {
    return _firestore
        .collection('reviews')
        .where('isFlagged', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }

  /// Check if a booking can be reviewed
  static Future<bool> canReviewBooking(String bookingId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return false;

      final bookingData = bookingDoc.data()!;
      final booking = Booking.fromMap(bookingData, id: bookingId);

      return booking.customerId == currentUser.uid &&
             booking.status == BookingStatus.completed &&
             !booking.hasReview;
    } catch (e) {
      AppLogger.error('Error checking if booking can be reviewed: $e');
      return false;
    }
  }

  /// Get existing review for a booking
  static Future<Review?> getBookingReview(String bookingId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final querySnapshot = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('customerId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return Review.fromMap(querySnapshot.docs.first.data(), id: querySnapshot.docs.first.id);
    } catch (e) {
      AppLogger.error('Error getting booking review: $e');
      return null;
    }
  }

  /// Update provider's average rating and review count
  static Future<void> _updateProviderRating(String providerId) async {
    try {
      // Get all reviews for this provider
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .where('isFlagged', isEqualTo: false)
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        // No reviews, set default values
        await _firestore.collection('providers').doc(providerId).update({
          'ratingAvg': 0.0,
          'ratingCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Calculate average rating
      double totalRating = 0.0;
      int reviewCount = reviewsSnapshot.docs.length;

      for (final doc in reviewsSnapshot.docs) {
        final rating = (doc.data()['rating'] as num).toDouble();
        totalRating += rating;
      }

      final averageRating = totalRating / reviewCount;

      // Update provider document
      await _firestore.collection('providers').doc(providerId).update({
        'ratingAvg': averageRating,
        'ratingCount': reviewCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Updated provider rating: $providerId - $averageRating ($reviewCount reviews)');
    } catch (e) {
      AppLogger.error('Error updating provider rating: $e');
      rethrow;
    }
  }

  /// Send notification to provider about new review
  static Future<void> _sendReviewNotification(String providerId, double rating, String customerName) async {
    try {
      // This would integrate with your notification service
      // For now, we'll just log it
      AppLogger.info('Review notification sent to provider $providerId: $rating stars from $customerName');
      
      // TODO: Integrate with actual notification service
      // await NotificationService.sendNotificationToUser(
      //   userId: providerId,
      //   title: 'New Review Received',
      //   body: 'You received a $rating star review from $customerName',
      //   type: 'review',
      // );
    } catch (e) {
      AppLogger.error('Error sending review notification: $e');
      // Don't rethrow - notification failure shouldn't break review creation
    }
  }

  /// Vote on review helpfulness
  static Future<void> voteReviewHelpful(String reviewId, bool isHelpful) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final reviewData = reviewDoc.data()!;
      final review = Review.fromMap(reviewData, id: reviewId);

      List<String> helpfulVotes = List<String>.from(review.helpfulVotes);

      if (isHelpful) {
        if (!helpfulVotes.contains(currentUser.uid)) {
          helpfulVotes.add(currentUser.uid);
        }
      } else {
        helpfulVotes.remove(currentUser.uid);
      }

      await _firestore.collection('reviews').doc(reviewId).update({
        'helpfulVotes': helpfulVotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Review vote updated: $reviewId');
    } catch (e) {
      AppLogger.error('Error voting on review: $e');
      rethrow;
    }
  }

  /// Get provider statistics
  static Future<Map<String, dynamic>> getProviderStats(String providerId) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .where('isFlagged', isEqualTo: false)
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
        };
      }

      double totalRating = 0.0;
      Map<String, int> ratingDistribution = {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};

      for (final doc in reviewsSnapshot.docs) {
        final rating = (doc.data()['rating'] as num).toDouble();
        totalRating += rating;
        
        final ratingKey = rating.floor().toString();
        if (ratingDistribution.containsKey(ratingKey)) {
          ratingDistribution[ratingKey] = ratingDistribution[ratingKey]! + 1;
        }
      }

      return {
        'totalReviews': reviewsSnapshot.docs.length,
        'averageRating': totalRating / reviewsSnapshot.docs.length,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      AppLogger.error('Error getting provider stats: $e');
      return {
        'totalReviews': 0,
        'averageRating': 0.0,
        'ratingDistribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
      };
    }
  }
}

