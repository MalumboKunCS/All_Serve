import 'package:cloud_firestore/cloud_firestore.dart';

class AdminServiceClient {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Approve provider verification
  Future<bool> approveProvider({
    required String providerId,
    required String adminUid,
    String? notes,
  }) async {
    try {
      print('AdminServiceClient: Approving provider: $providerId');
      
      // Update provider verification status
      await _firestore.collection('providers').doc(providerId).update({
        'verified': true,
        'verificationStatus': 'approved',
        'adminNotes': notes,
        'verifiedAt': Timestamp.now(),
        'verifiedBy': adminUid,
        'updatedAt': Timestamp.now(),
      });

      // Update verification queue
      final queueQuery = await _firestore
          .collection('verificationQueue')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in queueQuery.docs) {
        await doc.reference.update({
          'status': 'approved',
          'reviewedBy': adminUid,
          'reviewedAt': Timestamp.now(),
          'adminNotes': notes,
        });
      }

      print('AdminServiceClient: Provider approved successfully');
      return true;
    } catch (e) {
      print('AdminServiceClient: Error approving provider: $e');
      return false;
    }
  }

  // Reject provider verification
  Future<bool> rejectProvider({
    required String providerId,
    required String adminUid,
    required String reason,
  }) async {
    try {
      print('AdminServiceClient: Rejecting provider: $providerId');
      
      // Update provider verification status
      await _firestore.collection('providers').doc(providerId).update({
        'verified': false,
        'verificationStatus': 'rejected',
        'adminNotes': reason,
        'rejectedAt': Timestamp.now(),
        'rejectedBy': adminUid,
        'updatedAt': Timestamp.now(),
      });

      // Update verification queue
      final queueQuery = await _firestore
          .collection('verificationQueue')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in queueQuery.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'reviewedBy': adminUid,
          'reviewedAt': Timestamp.now(),
          'adminNotes': reason,
        });
      }

      print('AdminServiceClient: Provider rejected successfully');
      return true;
    } catch (e) {
      print('AdminServiceClient: Error rejecting provider: $e');
      return false;
    }
  }

  // Send announcement (simplified - just store in database)
  Future<bool> sendAnnouncement({
    required String title,
    required String message,
    required String audience,
    required String priority,
    required String type,
    required String adminUid,
    DateTime? expiresAt,
  }) async {
    try {
      print('AdminServiceClient: Sending announcement: $title');
      
      final announcementId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await _firestore.collection('announcements').doc(announcementId).set({
        'announcementId': announcementId,
        'title': title,
        'message': message,
        'audience': audience,
        'priority': priority,
        'type': type,
        'createdBy': adminUid,
        'createdAt': Timestamp.now(),
        'isActive': true,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'sentCount': 0,
      });

      print('AdminServiceClient: Announcement sent successfully');
      return true;
    } catch (e) {
      print('AdminServiceClient: Error sending announcement: $e');
      return false;
    }
  }

  // Get verification queue
  Future<List<Map<String, dynamic>>> getVerificationQueue() async {
    try {
      print('AdminServiceClient: Fetching verification queue');
      
      final query = await _firestore
          .collection('verificationQueue')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .get();

      final queue = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('AdminServiceClient: Found ${queue.length} pending verifications');
      return queue;
    } catch (e) {
      print('AdminServiceClient: Error fetching verification queue: $e');
      return [];
    }
  }

  // Get all providers
  Future<List<Map<String, dynamic>>> getAllProviders() async {
    try {
      print('AdminServiceClient: Fetching all providers');
      
      final query = await _firestore
          .collection('providers')
          .orderBy('createdAt', descending: true)
          .get();

      final providers = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('AdminServiceClient: Found ${providers.length} providers');
      return providers;
    } catch (e) {
      print('AdminServiceClient: Error fetching providers: $e');
      return [];
    }
  }

  // Get all users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      print('AdminServiceClient: Fetching all users');
      
      final query = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final users = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('AdminServiceClient: Found ${users.length} users');
      return users;
    } catch (e) {
      print('AdminServiceClient: Error fetching users: $e');
      return [];
    }
  }

  // Get all bookings
  Future<List<Map<String, dynamic>>> getAllBookings() async {
    try {
      print('AdminServiceClient: Fetching all bookings');
      
      final query = await _firestore
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .get();

      final bookings = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('AdminServiceClient: Found ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      print('AdminServiceClient: Error fetching bookings: $e');
      return [];
    }
  }

  // Get all reviews
  Future<List<Map<String, dynamic>>> getAllReviews() async {
    try {
      print('AdminServiceClient: Fetching all reviews');
      
      final query = await _firestore
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .get();

      final reviews = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('AdminServiceClient: Found ${reviews.length} reviews');
      return reviews;
    } catch (e) {
      print('AdminServiceClient: Error fetching reviews: $e');
      return [];
    }
  }

  // Flag review
  Future<bool> flagReview({
    required String reviewId,
    required String reason,
    required String adminUid,
  }) async {
    try {
      print('AdminServiceClient: Flagging review: $reviewId');
      
      await _firestore.collection('reviews').doc(reviewId).update({
        'flagged': true,
        'flagReason': reason,
        'flaggedAt': Timestamp.now(),
        'flaggedBy': adminUid,
      });

      print('AdminServiceClient: Review flagged successfully');
      return true;
    } catch (e) {
      print('AdminServiceClient: Error flagging review: $e');
      return false;
    }
  }

  // Suspend provider
  Future<bool> suspendProvider({
    required String providerId,
    required String reason,
    required String adminUid,
  }) async {
    try {
      print('AdminServiceClient: Suspending provider: $providerId');
      
      await _firestore.collection('providers').doc(providerId).update({
        'status': 'suspended',
        'suspendedAt': Timestamp.now(),
        'suspendedBy': adminUid,
        'suspensionReason': reason,
        'updatedAt': Timestamp.now(),
      });

      print('AdminServiceClient: Provider suspended successfully');
      return true;
    } catch (e) {
      print('AdminServiceClient: Error suspending provider: $e');
      return false;
    }
  }

  // Reactivate provider
  Future<bool> reactivateProvider({
    required String providerId,
    required String adminUid,
  }) async {
    try {
      print('AdminServiceClient: Reactivating provider: $providerId');
      
      await _firestore.collection('providers').doc(providerId).update({
        'status': 'active',
        'reactivatedAt': Timestamp.now(),
        'reactivatedBy': adminUid,
        'updatedAt': Timestamp.now(),
      });

      print('AdminServiceClient: Provider reactivated successfully');
      return true;
    } catch (e) {
      print('AdminServiceClient: Error reactivating provider: $e');
      return false;
    }
  }
}
