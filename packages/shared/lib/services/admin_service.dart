import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider.dart' as app_provider;
import '../models/user.dart';
import '../models/booking.dart';
import '../models/review.dart';
import '../models/announcement.dart';
import 'notification_service.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

enum VerificationStatus { pending, approved, rejected }
enum ProviderStatus { active, suspended, inactive, verified, rejected }

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Constants
  static const Duration _monthDuration = Duration(days: 30);

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
      // Update provider to be visible to customers
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': VerificationStatus.approved.name,
        'visibleToCustomers': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'adminNotes': adminNotes,
        'verifiedBy': 'admin', // In real app, use admin user ID
      });

      // Update verification queue
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('providerId', isEqualTo: providerId)
          .limit(1)
          .get();

      if (queueQuery.docs.isNotEmpty) {
        await queueQuery.docs.first.reference.update({
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'admin', // In real app, use admin user ID
          'adminRemarks': adminNotes,
        });
      }

      // Get provider data for notification
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      if (providerDoc.exists) {
        final providerData = providerDoc.data()!;
        final ownerUid = providerData['ownerUid'] as String;

        // Send notification to provider
        await NotificationService.sendNotificationToUser(
          userId: ownerUid,
          title: 'Business Registration Approved',
          body: 'Congratulations! Your business registration has been approved. You are now visible to customers.',
          data: {
            'type': 'admin',
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error approving provider: $e');
      return false;
    }
  }

  // Reject provider verification
  static Future<bool> rejectProvider(String providerId, String reason) async {
    try {
      // Keep provider hidden from customers
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': VerificationStatus.rejected.name,
        'visibleToCustomers': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'rejectedBy': 'admin', // In real app, use admin user ID
      });

      // Update verification queue
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('providerId', isEqualTo: providerId)
          .limit(1)
          .get();

      if (queueQuery.docs.isNotEmpty) {
        await queueQuery.docs.first.reference.update({
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'admin', // In real app, use admin user ID
          'adminRemarks': reason,
        });
      }

      // Get provider data for notification
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      if (providerDoc.exists) {
        final providerData = providerDoc.data()!;
        final ownerUid = providerData['ownerUid'] as String;

        // Send notification to provider
        await NotificationService.sendNotificationToUser(
          userId: ownerUid,
          title: 'Business Registration Rejected',
          body: 'Your business registration has been rejected. Please review the feedback and resubmit.',
          data: {
            'type': 'admin',
          },
        );
      }

      return true;
    } catch (e) {
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
        
        // Count approved and verified providers from providers collection
        final totalProviders = providersSnapshot.docs
            .where((doc) => 
                doc.data()['verified'] == true && 
                doc.data()['verificationStatus'] == 'approved')
            .length;

        // Count pending verifications from verification queue
        final pendingVerifications = verificationQueueSnapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length;

        // Count users with role 'customer'
        final totalCustomers = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'customer')
            .length;

        // Count users with role 'admin'
        final totalAdmins = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'admin')
            .length;

        return {
          'totalUsers': totalCustomers, // Display customer count as total users
          'totalProviders': totalProviders,
          'totalCustomers': totalCustomers,
          'totalAdmins': totalAdmins,
          'pendingVerifications': pendingVerifications,
        };
      } catch (e) {
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
        
        // Count approved and verified providers from providers collection
        final totalProviders = providersSnapshot.docs
            .where((doc) => 
                doc.data()['verified'] == true && 
                doc.data()['verificationStatus'] == 'approved')
            .length;

        // Count pending verifications from verification queue
        final pendingVerifications = verificationQueueSnapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length;

        // Count users with role 'customer'
        final totalCustomers = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'customer')
            .length;

        // Count users with role 'admin'
        final totalAdmins = usersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'admin')
            .length;

        return {
          'totalUsers': totalCustomers, // Display customer count as total users
          'totalProviders': totalProviders,
          'totalCustomers': totalCustomers,
          'totalAdmins': totalAdmins,
          'pendingVerifications': pendingVerifications,
        };
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return {};
    }
  }

  // Get system analytics
  static Future<Map<String, dynamic>> getSystemAnalytics() async {
    try {
      final now = DateTime.now();
      final lastMonth = now.subtract(_monthDuration);

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

  // Send announcement to all users (legacy method)
  static Future<bool> sendAnnouncement(String title, String message) async {
    return await sendTargetedAnnouncement(
      title: title,
      message: message,
      audience: 'all',
      priority: 'medium',
      type: 'info',
    );
  }

  // Send targeted announcement
  static Future<bool> sendTargetedAnnouncement({
    required String title,
    required String message,
    String audience = 'all', // 'all', 'customers', 'providers', 'specific'
    List<String> specificUserIds = const [],
    List<String> targetCategories = const [],
    String priority = 'medium', // 'low', 'medium', 'high', 'urgent'
    String type = 'info', // 'info', 'warning', 'promotion', 'maintenance', 'update'
    DateTime? expiresAt,
  }) async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        debugPrint('No current user found');
        return false;
      }

      final announcementData = {
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
        'isActive': true,
        'priority': priority,
        'type': type,
        'audience': audience,
        'specificUserIds': specificUserIds,
        'targetCategories': targetCategories,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'sentCount': 0, // Will be updated after sending
      };

      // Save announcement to database
      final docRef = await _firestore.collection('announcements').add(announcementData);

      // Send push notifications to targeted users
      final sentCount = await _sendTargetedAnnouncementNotifications(
        docRef.id,
        title,
        message,
        audience,
        specificUserIds,
        targetCategories,
      );

      // Update sent count
      await docRef.update({'sentCount': sentCount});

      return true;
    } catch (e) {
      debugPrint('Error sending targeted announcement: $e');
      return false;
    }
  }

  // Send targeted push notifications for announcement
  static Future<int> _sendTargetedAnnouncementNotifications(
    String announcementId,
    String title,
    String message,
    String audience,
    List<String> specificUserIds,
    List<String> targetCategories,
  ) async {
    try {
      List<String> deviceTokens = [];
      int recipientCount = 0;

      if (audience == 'specific' && specificUserIds.isNotEmpty) {
        // Send to specific users
        for (final userId in specificUserIds) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final data = userDoc.data()!;
            final tokens = List<String>.from(data['deviceTokens'] ?? []);
            deviceTokens.addAll(tokens);
            recipientCount++;
          }
        }
      } else {
        // Send based on audience
        Query query = _firestore.collection('users');
        
        switch (audience) {
          case 'customers':
            query = query.where('role', isEqualTo: 'customer');
            break;
          case 'providers':
            query = query.where('role', isEqualTo: 'provider');
            break;
          case 'admins':
            query = query.where('role', isEqualTo: 'admin');
            break;
          case 'all':
          default:
            // No filter needed for all users
            break;
        }

        final usersSnapshot = await query.get();
        
        for (final doc in usersSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final tokens = List<String>.from(data['deviceTokens'] ?? []);
          deviceTokens.addAll(tokens);
          recipientCount++;
        }
      }

      if (deviceTokens.isNotEmpty) {
        // Send notification to targeted users
        await NotificationService.sendNotificationToMultipleUsers(
          deviceTokens: deviceTokens,
          title: '📢 $title',
          body: message,
          data: {
            'type': 'announcement',
            'announcementId': announcementId,
            'audience': audience,
            'title': title,
            'message': message,
          },
        );
      }

      return recipientCount;
    } catch (e) {
      debugPrint('Error sending targeted announcement notifications: $e');
      return 0;
    }
  }

  // Get all announcements
  static Stream<List<Announcement>> getAnnouncementsStream() {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList());
  }

  // Get announcements for specific audience
  static Stream<List<Announcement>> getAnnouncementsForAudience(String audience) {
    return _firestore
        .collection('announcements')
        .where('audience', whereIn: [audience, 'all'])
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList());
  }

  // Update announcement status
  static Future<bool> updateAnnouncementStatus(String announcementId, bool isActive) async {
    try {
      await _firestore.collection('announcements').doc(announcementId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating announcement status: $e');
      return false;
    }
  }

  // Delete announcement
  static Future<bool> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore.collection('announcements').doc(announcementId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
      return false;
    }
  }

  // Get users for specific targeting
  static Future<List<User>> getUsersForTargeting() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      return usersSnapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting users for targeting: $e');
      return [];
    }
  }
}





