import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import 'notification_service.dart';


class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Create a new review
  static Future<String?> createReview({
    required String bookingId,
    required String customerId,
    required String providerId,
    required double rating,
    required String comment,
    List<String>? tags,
  }) async {
    try {
      // Verify that the customer can review this booking
      bool canReview = await _canCustomerReview(bookingId, customerId);
      if (!canReview) {
        throw Exception('You cannot review this booking');
      }
      
      // Check if review already exists
      bool reviewExists = await _reviewExists(bookingId, customerId);
      if (reviewExists) {
        throw Exception('You have already reviewed this booking');
      }
      
      // Create review document
      DocumentReference reviewRef = await _firestore.collection('reviews').add({
        'bookingId': bookingId,
        'customerId': customerId,
        'providerId': providerId,
        'rating': rating,
        'comment': comment,
        'tags': tags ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isVerified': false,
        'helpfulCount': 0,
        'reportedCount': 0,
        'status': 'active',
      });
      
      // Update provider's rating
      await _updateProviderRating(providerId);
      
      // Mark booking as reviewed
      await _firestore.collection('bookings').doc(bookingId).update({
        'reviewId': reviewRef.id,
        'rating': rating,
        'review': comment,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'New Review Received',
        body: 'You have received a new review from a customer',
        data: {
          'type': 'new_review',
          'reviewId': reviewRef.id,
          'bookingId': bookingId,
        },
      );
      
      return reviewRef.id;
    } catch (e) {
      rethrow;
    }
  }
  
  // Get reviews for a provider
  static Future<List<Review>> getProviderReviews({
    required String providerId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      Query query = _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId);
      
      query = query.orderBy('createdAt', descending: true).limit(limit);
      
      QuerySnapshot snapshot = await query.get();
      
      List<Review> reviews = [];
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Get customer data
        data['customer'] = await _getCustomerData(data['customerId']);
        
        reviews.add(Review.fromMap(data, id: doc.id));
      }
      
      return reviews;
    } catch (e) {
      return [];
    }
  }
  
  // Get reviews by a customer
  static Future<List<Review>> getCustomerReviews({
    required String customerId,
    int limit = 20,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reviews')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      List<Review> reviews = [];
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Get provider data
        data['provider'] = await _getProviderData(data['providerId']);
        
        reviews.add(Review.fromMap(data, id: doc.id));
      }
      
      return reviews;
    } catch (e) {
      return [];
    }
  }
  
  // Update a review
  static Future<bool> updateReview({
    required String reviewId,
    required String customerId,
    double? rating,
    String? comment,
    List<String>? tags,
  }) async {
    try {
      // Verify ownership
      DocumentSnapshot reviewDoc = await _firestore
          .collection('reviews')
          .doc(reviewId)
          .get();
      
      if (!reviewDoc.exists) {
        return false;
      }
      
      Map<String, dynamic> reviewData = reviewDoc.data() as Map<String, dynamic>;
      if (reviewData['customerId'] != customerId) {
        return false;
      }
      
      // Check if review can be updated (within 24 hours)
      DateTime createdAt = (reviewData['createdAt'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      if (now.difference(createdAt).inHours > 24) {
        throw Exception('Reviews can only be updated within 24 hours');
      }
      
      // Update review
      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (rating != null) {
        updateData['rating'] = rating;
      }
      
      if (comment != null) {
        updateData['comment'] = comment;
      }
      
      if (tags != null) {
        updateData['tags'] = tags;
      }
      
      await _firestore.collection('reviews').doc(reviewId).update(updateData);
      
      // Update provider rating if rating changed
      if (rating != null) {
        await _updateProviderRating(reviewData['providerId']);
      }
      
      return true;
    } catch (e) {
      rethrow;
    }
  }
  
  // Delete a review
  static Future<bool> deleteReview({
    required String reviewId,
    required String customerId,
  }) async {
    try {
      // Verify ownership
      DocumentSnapshot reviewDoc = await _firestore
          .collection('reviews')
          .doc(reviewId)
          .get();
      
      if (!reviewDoc.exists) {
        return false;
      }
      
      Map<String, dynamic> reviewData = reviewDoc.data() as Map<String, dynamic>;
      if (reviewData['customerId'] != customerId) {
        return false;
      }
      
      // Check if review can be deleted (within 24 hours)
      DateTime createdAt = (reviewData['createdAt'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      if (now.difference(createdAt).inHours > 24) {
        throw Exception('Reviews can only be deleted within 24 hours');
      }
      
      // Delete review
      await _firestore.collection('reviews').doc(reviewId).delete();
      
      // Update provider rating
      await _updateProviderRating(reviewData['providerId']);
      
      // Remove review from booking
      await _firestore.collection('bookings').doc(reviewData['bookingId']).update({
        'reviewId': null,
        'rating': null,
        'review': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      rethrow;
    }
  }
  
  // Report a review
  static Future<bool> reportReview({
    required String reviewId,
    required String reporterId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      // Check if user already reported this review
      bool alreadyReported = await _userAlreadyReported(reviewId, reporterId);
      if (alreadyReported) {
        throw Exception('You have already reported this review');
      }
      
      // Create report
      await _firestore.collection('review_reports').add({
        'reviewId': reviewId,
        'reporterId': reporterId,
        'reason': reason,
        'additionalDetails': additionalDetails,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      // Increment report count on review
      await _firestore.collection('reviews').doc(reviewId).update({
        'reportedCount': FieldValue.increment(1),
      });
      
      // Check if review should be automatically hidden (5+ reports)
      DocumentSnapshot reviewDoc = await _firestore
          .collection('reviews')
          .doc(reviewId)
          .get();
      
      if (reviewDoc.exists) {
        Map<String, dynamic> reviewData = reviewDoc.data() as Map<String, dynamic>;
        int reportedCount = reviewData['reportedCount'] ?? 0;
        
        if (reportedCount >= 5) {
          await _firestore.collection('reviews').doc(reviewId).update({
            'status': 'hidden',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      return true;
    } catch (e) {
      rethrow;
    }
  }
  
  // Mark review as helpful
  static Future<bool> markReviewHelpful({
    required String reviewId,
    required String userId,
  }) async {
    try {
      // Check if user already marked as helpful
      bool alreadyMarked = await _userAlreadyMarkedHelpful(reviewId, userId);
      if (alreadyMarked) {
        // Remove helpful mark
        await _firestore.collection('review_helpful').doc('${reviewId}_$userId').delete();
        await _firestore.collection('reviews').doc(reviewId).update({
          'helpfulCount': FieldValue.increment(-1),
        });
        return true;
      }
      
      // Add helpful mark
      await _firestore.collection('review_helpful').doc('${reviewId}_$userId').set({
        'reviewId': reviewId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('reviews').doc(reviewId).update({
        'helpfulCount': FieldValue.increment(1),
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Get review statistics for a provider
  static Future<Map<String, dynamic>> getProviderReviewStats(String providerId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)

          .get();
      
      if (snapshot.docs.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'ratingDistribution': {},
          'totalHelpful': 0,
        };
      }
      
      double totalRating = 0.0;
      Map<String, int> ratingDistribution = {};
      int totalHelpful = 0;
      
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        double rating = (data['rating'] ?? 0).toDouble();
        totalRating += rating;
        
        String ratingKey = rating.floor().toString();
        ratingDistribution[ratingKey] = (ratingDistribution[ratingKey] ?? 0) + 1;
        
        totalHelpful += (data['helpfulCount'] as int? ?? 0);
      }
      
      double averageRating = totalRating / snapshot.docs.length;
      
      return {
        'totalReviews': snapshot.docs.length,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
        'totalHelpful': totalHelpful,
      };
    } catch (e) {
      return {
        'totalReviews': 0,
        'averageRating': 0.0,
        'ratingDistribution': {},
        'totalHelpful': 0,
      };
    }
  }
  
  // Verify that customer can review a booking
  static Future<bool> _canCustomerReview(String bookingId, String customerId) async {
    try {
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (!bookingDoc.exists) {
        return false;
      }
      
      Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
      
      // Check if customer owns the booking
      if (bookingData['customerId'] != customerId) {
        return false;
      }
      
      // Check if booking is completed
      if (bookingData['status'] != 'completed') {
        return false;
      }
      
      // Check if booking was completed within last 30 days
      if (bookingData['completionDate'] != null) {
        DateTime completionDate = (bookingData['completionDate'] as Timestamp).toDate();
        DateTime now = DateTime.now();
        if (now.difference(completionDate).inDays > 30) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Check if review already exists
  static Future<bool> _reviewExists(String bookingId, String customerId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('customerId', isEqualTo: customerId)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // Update provider's average rating
  static Future<void> _updateProviderRating(String providerId) async {
    try {
      QuerySnapshot reviews = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .get();
      
      if (reviews.docs.isEmpty) {
        await _firestore.collection('providers').doc(providerId).update({
          'rating': 0.0,
          'reviewCount': 0,
        });
        return;
      }
      
      double totalRating = 0.0;
      for (DocumentSnapshot doc in reviews.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalRating += (data['rating'] ?? 0).toDouble();
      }
      
      double averageRating = totalRating / reviews.docs.length;
      
      await _firestore.collection('providers').doc(providerId).update({
        'rating': averageRating,
        'reviewCount': reviews.docs.length,
      });
    } catch (e) {
      // Handle error silently
    }
  }
  
  // Check if user already reported a review
  static Future<bool> _userAlreadyReported(String reviewId, String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('review_reports')
          .where('reviewId', isEqualTo: reviewId)
          .where('reporterId', isEqualTo: userId)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // Check if user already marked review as helpful
  static Future<bool> _userAlreadyMarkedHelpful(String reviewId, String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('review_helpful')
          .doc('${reviewId}_$userId')
          .get();
      
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
  
  // Get customer data
  static Future<Map<String, dynamic>?> _getCustomerData(String customerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(customerId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Get provider data
  static Future<Map<String, dynamic>?> _getProviderData(String providerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
