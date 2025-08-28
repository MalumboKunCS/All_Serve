import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider.dart' as app_provider;
import 'notification_service.dart';
import 'package:flutter/foundation.dart';

enum VerificationStatus { pending, approved, rejected }
enum ProviderStatus { active, suspended, inactive, verified, rejected }

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all providers pending verification
  static Stream<List<app_provider.Provider>> getPendingVerifications() {
    return _firestore
        .collection('providers')
        .where('verificationStatus', isEqualTo: VerificationStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return app_provider.Provider.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }

  // Get all providers (for admin overview)
  static Stream<List<app_provider.Provider>> getAllProviders() {
    return _firestore
        .collection('providers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return app_provider.Provider.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }

  // Approve provider verification
  static Future<bool> approveProvider(String providerId, String adminNotes) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': VerificationStatus.approved.name,
        'status': ProviderStatus.verified.name,
        'verifiedAt': FieldValue.serverTimestamp(),
        'adminNotes': adminNotes,
        'verifiedBy': 'admin', // In real app, use admin user ID
      });

      // Send notification to provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'Verification Approved',
        body: 'Congratulations! Your provider account has been verified. You can now receive bookings.',
        data: {
          'type': 'verification_approved',
        },
      );

      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error approving provider: $e');
      return false;
    }
  }

  // Reject provider verification
  static Future<bool> rejectProvider(String providerId, String reason) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': VerificationStatus.rejected.name,
        'status': ProviderStatus.rejected.name,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'rejectedBy': 'admin', // In real app, use admin user ID
      });

      // Send notification to provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'Verification Rejected',
        body: 'Your verification has been rejected. Please check the reason and resubmit valid documents.',
        data: {
          'type': 'verification_rejected',
          'reason': reason,
        },
      );

      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error rejecting provider: $e');
      return false;
    }
  }

  // Suspend provider
  static Future<bool> suspendProvider(String providerId, String reason) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'status': ProviderStatus.suspended.name,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspensionReason': reason,
        'suspendedBy': 'admin', // In real app, use admin user ID
      });

      // Send notification to provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'Account Suspended',
        body: 'Your account has been suspended. Please contact support for more information.',
        data: {
          'type': 'account_suspended',
          'reason': reason,
        },
      );

      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error suspending provider: $e');
      return false;
    }
  }

  // Reactivate suspended provider
  static Future<bool> reactivateProvider(String providerId) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'status': ProviderStatus.verified.name,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': 'admin', // In real app, use admin user ID
      });

      // Send notification to provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'Account Reactivated',
        body: 'Your account has been reactivated. You can now receive bookings again.',
        data: {
          'type': 'account_reactivated',
        },
      );

      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error reactivating provider: $e');
      return false;
    }
  }

  // Get admin dashboard stats
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final providersSnapshot = await _firestore.collection('providers').get();
      final bookingsSnapshot = await _firestore.collection('bookings').get();
      final usersSnapshot = await _firestore.collection('users').get();

      int totalProviders = providersSnapshot.docs.length;
      int totalBookings = bookingsSnapshot.docs.length;
      int totalUsers = usersSnapshot.docs.length;

      int pendingVerifications = providersSnapshot.docs
          .where((doc) => doc.data()['verificationStatus'] == VerificationStatus.pending.name)
          .length;

      int activeProviders = providersSnapshot.docs
          .where((doc) => doc.data()['status'] == ProviderStatus.verified.name)
          .length;

      int suspendedProviders = providersSnapshot.docs
          .where((doc) => doc.data()['status'] == ProviderStatus.suspended.name)
          .length;

      return {
        'totalProviders': totalProviders,
        'totalBookings': totalBookings,
        'totalUsers': totalUsers,
        'pendingVerifications': pendingVerifications,
        'activeProviders': activeProviders,
        'suspendedProviders': suspendedProviders,
      };
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting dashboard stats: $e');
      return {};
    }
  }

  // Get system analytics
  static Future<Map<String, dynamic>> getSystemAnalytics() async {
    try {
      final now = DateTime.now();
      final lastMonth = now.subtract(Duration(days: 30));

      // Get monthly provider registrations
      final monthlyProviders = await _firestore
          .collection('providers')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .get();

      // Get monthly bookings
      final monthlyBookings = await _firestore
          .collection('bookings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .get();

      // Get monthly revenue (if payment tracking is implemented)
      double monthlyRevenue = 0.0; // TODO: Implement payment tracking

      return {
        'monthlyProviderRegistrations': monthlyProviders.docs.length,
        'monthlyBookings': monthlyBookings.docs.length,
        'monthlyRevenue': monthlyRevenue,
        'period': 'Last 30 days',
      };
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting system analytics: $e');
      return {};
    }
  }

  // Send system-wide notification
  static Future<bool> sendSystemNotification({
    required String title,
    required String body,
    String? targetAudience, // 'all', 'providers', 'customers'
    Map<String, dynamic>? data,
  }) async {
    try {
      String collection = 'users';
      if (targetAudience == 'providers') {
        collection = 'providers';
      }

      final usersSnapshot = await _firestore.collection(collection).get();
      
      for (final doc in usersSnapshot.docs) {
        await NotificationService.sendNotificationToUser(
          userId: doc.id,
          title: title,
          body: body,
          data: data,
        );
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error sending system notification: $e');
      return false;
    }
  }
}




