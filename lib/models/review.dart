import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String userId;
  final String providerId;
  final String bookingId;
  final double rating; // 1-5 stars
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? images; // URLs to review images

  Review({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.bookingId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
    this.images,
  });

  factory Review.fromMap(Map<String, dynamic> data, String id) {
    return Review(
      id: id,
      userId: data['userId'] ?? '',
      providerId: data['providerId'] ?? '',
      bookingId: data['bookingId'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      images: data['images'] != null 
          ? List<String>.from(data['images']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'providerId': providerId,
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'images': images,
    };
  }
}

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a review
  Future<bool> submitReview({
    required String userId,
    required String providerId,
    required String bookingId,
    required double rating,
    String? comment,
    List<String>? images,
  }) async {
    try {
      // Check if review already exists for this booking
      final existingReview = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingReview.docs.isNotEmpty) {
        // Update existing review
        await _firestore
            .collection('reviews')
            .doc(existingReview.docs.first.id)
            .update({
          'rating': rating,
          'comment': comment,
          'images': images,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new review
        final review = Review(
          id: '',
          userId: userId,
          providerId: providerId,
          bookingId: bookingId,
          rating: rating,
          comment: comment,
          createdAt: DateTime.now(),
          images: images,
        );

        await _firestore.collection('reviews').add(review.toMap());
      }

      // Update provider's average rating
      await _updateProviderRating(providerId);

      return true;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }

  // Update provider's average rating
  Future<void> _updateProviderRating(String providerId) async {
    try {
      final reviews = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .get();

      if (reviews.docs.isNotEmpty) {
        double totalRating = 0;
        int reviewCount = reviews.docs.length;

        for (final doc in reviews.docs) {
          totalRating += (doc.data()['rating'] ?? 0).toDouble();
        }

        double averageRating = totalRating / reviewCount;

        // Update provider document with new rating
        await _firestore.collection('providers').doc(providerId).update({
          'rating': averageRating,
          'reviews': reviewCount,
          'ratingUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating provider rating: $e');
    }
  }

  // Get reviews for a provider
  Stream<List<Review>> getProviderReviews(String providerId) {
    return _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get reviews by a user
  Stream<List<Review>> getUserReviews(String userId) {
    return _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Review.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Check if user can review a booking
  Future<bool> canReviewBooking(String userId, String bookingId) async {
    try {
      // Check if booking is completed
      final booking = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!booking.exists) return false;

      final bookingData = booking.data()!;
      if (bookingData['userId'] != userId) return false;
      if (bookingData['status'] != 'completed') return false;

      // Check if review already exists
      final existingReview = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('userId', isEqualTo: userId)
          .get();

      return existingReview.docs.isEmpty;
    } catch (e) {
      print('Error checking review eligibility: $e');
      return false;
    }
  }

  // Get existing review for a booking
  Future<Review?> getBookingReview(String bookingId, String userId) async {
    try {
      final reviews = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('userId', isEqualTo: userId)
          .get();

      if (reviews.docs.isNotEmpty) {
        return Review.fromMap(reviews.docs.first.data(), reviews.docs.first.id);
      }
      return null;
    } catch (e) {
      print('Error getting booking review: $e');
      return null;
    }
  }

  // Delete a review
  Future<bool> deleteReview(String reviewId, String providerId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
      
      // Update provider's average rating
      await _updateProviderRating(providerId);
      
      return true;
    } catch (e) {
      print('Error deleting review: $e');
      return false;
    }
  }

  // Get provider rating statistics
  Future<Map<String, dynamic>> getProviderRatingStats(String providerId) async {
    try {
      final reviews = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .get();

      if (reviews.docs.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalReviews': 0,
          'ratingDistribution': [0, 0, 0, 0, 0], // 1-star to 5-star counts
        };
      }

      double totalRating = 0;
      List<int> distribution = [0, 0, 0, 0, 0];

      for (final doc in reviews.docs) {
        final rating = (doc.data()['rating'] ?? 0).toDouble();
        totalRating += rating;
        
        // Count distribution (rating 1.0-1.9 = index 0, 2.0-2.9 = index 1, etc.)
        int ratingIndex = (rating - 1).clamp(0, 4).toInt();
        distribution[ratingIndex]++;
      }

      return {
        'averageRating': totalRating / reviews.docs.length,
        'totalReviews': reviews.docs.length,
        'ratingDistribution': distribution,
      };
    } catch (e) {
      print('Error getting rating stats: $e');
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'ratingDistribution': [0, 0, 0, 0, 0],
      };
    }
  }
}

