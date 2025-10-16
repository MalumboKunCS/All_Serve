import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import '../utils/app_logger.dart';

class ReviewServiceClient {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Client-side review creation with validation
  Future<String> createReview({
    required String bookingId,
    required String customerId,
    required String providerId,
    required double rating,
    required String comment,
  }) async {
    try {
      AppLogger.info('ReviewServiceClient: Creating review for booking: $bookingId');
      
      // 1. Validate booking exists and is completed
      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data()!;
      if (bookingData['status'] != 'completed') {
        throw Exception('Can only review completed bookings');
      }

      if (bookingData['customerId'] != customerId) {
        throw Exception('Unauthorized to review this booking');
      }

      AppLogger.info('ReviewServiceClient: Booking validation passed');

      // 2. Check if review already exists
      final existingReviewQuery = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('customerId', isEqualTo: customerId)
          .get();

      if (existingReviewQuery.docs.isNotEmpty) {
        throw Exception('Review already exists for this booking');
      }

      AppLogger.info('ReviewServiceClient: No existing review found');

      // 3. Create review
      final reviewId = DateTime.now().millisecondsSinceEpoch.toString();
      final review = {
        'reviewId': reviewId,
        'bookingId': bookingId,
        'customerId': customerId,
        'providerId': providerId,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.now(),
        'flagged': false,
        'helpfulVotes': [],
      };

      await _firestore.collection('reviews').doc(reviewId).set(review);

      AppLogger.info('ReviewServiceClient: Review created successfully with ID: $reviewId');

      // 4. Update provider rating
      await _updateProviderRating(providerId);

      return reviewId;
    } catch (e) {
      AppLogger.info('ReviewServiceClient: Error creating review: $e');
      rethrow;
    }
  }

  // Update existing review
  Future<bool> updateReview({
    required String reviewId,
    required String customerId,
    required double rating,
    required String comment,
  }) async {
    try {
      AppLogger.info('ReviewServiceClient: Updating review: $reviewId');
      
      // Verify user owns the review
      final reviewDoc = await _firestore
          .collection('reviews')
          .doc(reviewId)
          .get();

      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final reviewData = reviewDoc.data()!;
      if (reviewData['customerId'] != customerId) {
        throw Exception('Unauthorized to update this review');
      }

      // Update review
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': rating,
        'comment': comment,
        'updatedAt': Timestamp.now(),
      });

      AppLogger.info('ReviewServiceClient: Review updated successfully');

      // Update provider rating
      await _updateProviderRating(reviewData['providerId']);

      return true;
    } catch (e) {
      AppLogger.info('ReviewServiceClient: Error updating review: $e');
      return false;
    }
  }

  // Get existing review for booking
  Future<Review?> getReviewForBooking({
    required String bookingId,
    required String customerId,
  }) async {
    try {
      final query = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('customerId', isEqualTo: customerId)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        return Review.fromMap(data, id: query.docs.first.id);
      }

      return null;
    } catch (e) {
      AppLogger.info('ReviewServiceClient: Error getting review for booking: $e');
      return null;
    }
  }

  // Get provider reviews
  Future<List<Review>> getProviderReviews({
    required String providerId,
    int limit = 20,
  }) async {
    try {
      AppLogger.info('ReviewServiceClient: Fetching reviews for provider: $providerId');
      
      final query = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .where('flagged', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      
      final reviews = snapshot.docs.map((doc) {
        final data = doc.data();
        return Review.fromMap(data, id: doc.id);
      }).toList();

      AppLogger.info('ReviewServiceClient: Found ${reviews.length} reviews');
      return reviews;
    } catch (e) {
      AppLogger.info('ReviewServiceClient: Error fetching provider reviews: $e');
      return [];
    }
  }

  // Flag review
  Future<bool> flagReview({
    required String reviewId,
    required String reason,
  }) async {
    try {
      AppLogger.info('ReviewServiceClient: Flagging review: $reviewId');
      
      await _firestore.collection('reviews').doc(reviewId).update({
        'flagged': true,
        'flagReason': reason,
        'flaggedAt': Timestamp.now(),
      });

      AppLogger.info('ReviewServiceClient: Review flagged successfully');
      return true;
    } catch (e) {
      AppLogger.info('ReviewServiceClient: Error flagging review: $e');
      return false;
    }
  }

  // Update provider average rating
  Future<void> _updateProviderRating(String providerId) async {
    try {
      AppLogger.info('ReviewServiceClient: Updating provider rating for: $providerId');
      
      final reviewsQuery = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .where('flagged', isEqualTo: false)
          .get();

      if (reviewsQuery.docs.isEmpty) {
        // No reviews, set rating to 0
        await _firestore.collection('providers').doc(providerId).update({
          'ratingAvg': 0.0,
          'ratingCount': 0,
        });
        return;
      }

      final ratings = reviewsQuery.docs
          .map((doc) => (doc.data()['rating'] as num).toDouble())
          .toList();

      final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

      await _firestore.collection('providers').doc(providerId).update({
        'ratingAvg': averageRating,
        'ratingCount': ratings.length,
      });

      AppLogger.info('ReviewServiceClient: Provider rating updated - Avg: $averageRating, Count: ${ratings.length}');
    } catch (e) {
      AppLogger.info('ReviewServiceClient: Error updating provider rating: $e');
    }
  }

  // Vote on review helpfulness
  Future<bool> voteOnReview({
    required String reviewId,
    required String userId,
    required bool isHelpful,
  }) async {
    try {
      AppLogger.info('ReviewServiceClient: Voting on review: $reviewId');
      
      final reviewDoc = await _firestore
          .collection('reviews')
          .doc(reviewId)
          .get();

      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final reviewData = reviewDoc.data()!;
      final helpfulVotes = List<String>.from(reviewData['helpfulVotes'] ?? []);

      if (isHelpful) {
        if (!helpfulVotes.contains(userId)) {
          helpfulVotes.add(userId);
        }
      } else {
        helpfulVotes.remove(userId);
      }

      await _firestore.collection('reviews').doc(reviewId).update({
        'helpfulVotes': helpfulVotes,
      });

      AppLogger.info('ReviewServiceClient: Vote recorded successfully');
      return true;
    } catch (e) {
      AppLogger.info('ReviewServiceClient: Error voting on review: $e');
      return false;
    }
  }
}
