import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:all_server/models/provider.dart';
import 'package:all_server/services/notification_service.dart';
import 'package:flutter/foundation.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Get all providers pending verification
  Stream<List<Provider>> getPendingVerifications() {
    return _firestore
        .collection('providers')
        .where('verificationStatus', isEqualTo: VerificationStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Provider.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get all providers (for admin overview)
  Stream<List<Provider>> getAllProviders() {
    return _firestore
        .collection('providers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Provider.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Approve provider verification
  Future<bool> approveProvider(String providerId, String adminNotes) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': VerificationStatus.approved.name,
        'status': ProviderStatus.verified.name,
        'verifiedAt': FieldValue.serverTimestamp(),
        'adminNotes': adminNotes,
        'verifiedBy': 'admin', // In real app, use admin user ID
      });

      // Send notification to provider
      await _notificationService.sendNotificationToUser(
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
  Future<bool> rejectProvider(String providerId, String reason) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': VerificationStatus.rejected.name,
        'status': ProviderStatus.rejected.name,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'rejectedBy': 'admin', // In real app, use admin user ID
      });

      // Send notification to provider
      await _notificationService.sendNotificationToUser(
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
  Future<bool> suspendProvider(String providerId, String reason) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'status': ProviderStatus.suspended.name,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspensionReason': reason,
        'suspendedBy': 'admin',
      });

      // Send notification to provider
      await _notificationService.sendNotificationToUser(
        userId: providerId,
        title: 'Account Suspended',
        body: 'Your provider account has been suspended. Please contact support for more information.',
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

  // Reactivate provider
  Future<bool> reactivateProvider(String providerId) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'status': ProviderStatus.verified.name,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': 'admin',
      });

      // Send notification to provider
      await _notificationService.sendNotificationToUser(
        userId: providerId,
        title: 'Account Reactivated',
        body: 'Your provider account has been reactivated. You can now receive bookings again.',
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

  // Get admin dashboard statistics
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final providersSnapshot = await _firestore.collection('providers').get();
      final bookingsSnapshot = await _firestore.collection('bookings').get();
      final usersSnapshot = await _firestore.collection('users').get();

      final providers = providersSnapshot.docs.map((doc) => 
        Provider.fromMap(doc.data(), doc.id)).toList();

      int pendingVerifications = providers
          .where((p) => p.verificationStatus == VerificationStatus.pending)
          .length;
      
      int verifiedProviders = providers
          .where((p) => p.status == ProviderStatus.verified)
          .length;

      int suspendedProviders = providers
          .where((p) => p.status == ProviderStatus.suspended)
          .length;

      return {
        'totalUsers': usersSnapshot.docs.length,
        'totalProviders': providers.length,
        'verifiedProviders': verifiedProviders,
        'pendingVerifications': pendingVerifications,
        'suspendedProviders': suspendedProviders,
        'totalBookings': bookingsSnapshot.docs.length,
      };
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting admin stats: $e');
      return {};
    }
  }

  // Send announcement to all providers
  Future<bool> sendAnnouncementToProviders(String title, String message) async {
    try {
      final providersSnapshot = await _firestore.collection('providers').get();
      
      for (final doc in providersSnapshot.docs) {
        await _notificationService.sendNotificationToUser(
          userId: doc.id,
          title: title,
          body: message,
          data: {
            'type': 'admin_announcement',
          },
        );
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error sending announcement: $e');
      return false;
    }
  }

  // Get provider by ID with admin view
  Future<Provider?> getProviderForAdmin(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      if (doc.exists) {
        return Provider.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting provider: $e');
      return null;
    }
  }
}




