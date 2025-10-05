import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider.dart' as app_provider;
import '../models/user.dart';
import '../models/booking.dart';
import '../models/review.dart';
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

  // Get admin dashboard stats stream for real-time updates
  static Stream<Map<String, dynamic>> getDashboardStatsStream() {
    return _firestore.collection('providers').snapshots().asyncMap((providersSnapshot) async {
      try {
        final usersSnapshot = await _firestore.collection('users').get();
        final verificationQueueSnapshot = await _firestore.collection('verification_queue').get();

        int totalUsers = usersSnapshot.docs.length;
        
        // Count approved and verified providers from providers collection
        int totalProviders = providersSnapshot.docs
            .where((doc) => 
                doc.data()['verified'] == true && 
                doc.data()['verificationStatus'] == 'approved')
            .length;

        // Count pending verifications from verification queue
        int pendingVerifications = verificationQueueSnapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length;

        // Count users with role 'customer' (this will be displayed as "Total Customers")
        int totalCustomers = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'customer')
            .length;

        // Count users with role 'admin'
        int totalAdmins = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'admin')
            .length;

        return {
          'totalUsers': totalCustomers, // Changed to show customer count
          'totalProviders': totalProviders,
          'totalCustomers': totalCustomers,
          'totalAdmins': totalAdmins,
          'pendingVerifications': pendingVerifications,
        };
      } catch (e) {
        // ignore: avoid_print
        debugPrint('Error getting dashboard stats stream: $e');
        return {};
      }
    });
  }

  // Get admin dashboard stats
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final providersSnapshot = await _firestore.collection('providers').get();
      final verificationQueueSnapshot = await _firestore.collection('verification_queue').get();

        int totalUsers = usersSnapshot.docs.length;
        
        // Count approved and verified providers from providers collection
        int totalProviders = providersSnapshot.docs
            .where((doc) => 
                doc.data()['verified'] == true && 
                doc.data()['verificationStatus'] == 'approved')
            .length;

        // Count pending verifications from verification queue
        int pendingVerifications = verificationQueueSnapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length;

        // Count users with role 'customer' (this will be displayed as "Total Customers")
        int totalCustomers = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'customer')
            .length;

        // Count users with role 'admin'
        int totalAdmins = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'admin')
            .length;

        return {
          'totalUsers': totalCustomers, // Changed to show customer count
          'totalProviders': totalProviders,
          'totalCustomers': totalCustomers,
          'totalAdmins': totalAdmins,
          'pendingVerifications': pendingVerifications,
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

  // Get recent users (last 10)
  static Future<List<User>> getRecentUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return User(
          uid: doc.id,
          email: data['email'] ?? '',
          name: data['name'] ?? '',
          phone: data['phone'] ?? '',
          role: data['role'] ?? 'customer',
          profileImageUrl: data['profileImageUrl'],
          deviceTokens: List<String>.from(data['deviceTokens'] ?? []),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          is2FAEnabled: data['is2FAEnabled'] ?? false,
          twoFactorSecret: data['twoFactorSecret'],
          backupCodes: List<String>.from(data['backupCodes'] ?? []),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting recent users: $e');
      return [];
    }
  }

  // Get recent bookings (last 10)
  static Future<List<Booking>> getRecentBookings() async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .orderBy('requestedAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        return Booking.fromFirestore(doc);
      }).toList();
    } catch (e) {
      debugPrint('Error getting recent bookings: $e');
      return [];
    }
  }

  // Get pending providers from verification queue
  static Future<List<app_provider.Provider>> getPendingProviders() async {
    try {
      final snapshot = await _firestore
          .collection('verification_queue')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .get();

      List<app_provider.Provider> providers = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final providerId = data['providerId'] as String?;
        
        if (providerId != null) {
          try {
            final providerDoc = await _firestore
                .collection('providers')
                .doc(providerId)
                .get();
            
            if (providerDoc.exists) {
              final providerData = providerDoc.data()!;
              providers.add(app_provider.Provider.fromMap(providerData, id: providerId));
            }
          } catch (e) {
            debugPrint('Error fetching provider $providerId: $e');
          }
        }
      }
      
      return providers;
    } catch (e) {
      debugPrint('Error getting pending providers: $e');
      return [];
    }
  }

  // Get flagged reviews
  static Future<List<Review>> getFlaggedReviews() async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('isFlagged', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Review.fromFirestore(doc);
      }).toList();
    } catch (e) {
      debugPrint('Error getting flagged reviews: $e');
      return [];
    }
  }

  // Send announcement to all users
  static Future<bool> sendAnnouncement(String title, String message) async {
    try {
      final announcementData = {
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _firestore.collection('users').doc(), // Current admin user
        'isActive': true,
        'priority': 'normal', // normal, high, urgent
        'targetAudience': 'all', // all, customers, providers, specific
      };

      // Save announcement to database
      await _firestore.collection('announcements').add(announcementData);

      // Send push notifications to all users
      await _sendAnnouncementNotifications(title, message);

      return true;
    } catch (e) {
      debugPrint('Error sending announcement: $e');
      return false;
    }
  }

  // Send push notifications for announcement
  static Future<void> _sendAnnouncementNotifications(String title, String message) async {
    try {
      // Get all users with device tokens
      final usersSnapshot = await _firestore.collection('users').get();
      
      List<String> deviceTokens = [];
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final tokens = List<String>.from(data['deviceTokens'] ?? []);
        deviceTokens.addAll(tokens);
      }

      if (deviceTokens.isNotEmpty) {
        // Send notification to all users
        await NotificationService.sendNotificationToMultipleUsers(
          deviceTokens: deviceTokens,
          title: '📢 $title',
          body: message,
          data: {
            'type': 'announcement',
            'title': title,
            'message': message,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending announcement notifications: $e');
    }
  }
}





