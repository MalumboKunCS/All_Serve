import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AdminNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notify admins about new provider registration
  static Future<void> notifyNewProviderRegistration({
    required String providerId,
    required String providerName,
    required String businessName,
  }) async {
    try {
      // Get all admin users
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminQuery.docs) {
        final adminData = adminDoc.data();
        final deviceTokens = List<String>.from(adminData['deviceTokens'] ?? []);
        
        if (deviceTokens.isNotEmpty) {
          await NotificationService.sendNotificationToUser(
            userId: adminDoc.id,
            title: 'New Provider Registration',
            body: '$providerName ($businessName) has submitted their registration for review',
            data: {
              'type': 'provider_verification',
              'providerId': providerId,
              'action': 'review_required',
            },
          );
        }
      }

      // Also create an in-app notification
      await _createInAppNotification(
        title: 'New Provider Registration',
        body: '$providerName ($businessName) has submitted their registration for review',
        type: 'provider_verification',
        data: {'providerId': providerId},
        targetRole: 'admin',
      );
    } catch (e) {
      print('Error notifying admins about new provider registration: $e');
    }
  }

  // Notify admins about document updates
  static Future<void> notifyDocumentUpdate({
    required String providerId,
    required String providerName,
    required String documentType,
  }) async {
    try {
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminQuery.docs) {
        final adminData = adminDoc.data();
        final deviceTokens = List<String>.from(adminData['deviceTokens'] ?? []);
        
        if (deviceTokens.isNotEmpty) {
          await NotificationService.sendNotificationToUser(
            userId: adminDoc.id,
            title: 'Document Update',
            body: '$providerName has updated their $documentType',
            data: {
              'type': 'document_update',
              'providerId': providerId,
              'documentType': documentType,
            },
          );
        }
      }
    } catch (e) {
      print('Error notifying admins about document update: $e');
    }
  }

  // Notify provider about verification status change
  static Future<void> notifyProviderVerificationStatus({
    required String providerId,
    required String status, // 'approved', 'rejected', 'pending'
    required String? reason,
    required String adminName,
  }) async {
    try {
      // Get provider data
      final providerDoc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();

      if (!providerDoc.exists) return;

      final providerData = providerDoc.data()!;
      final ownerUid = providerData['ownerUid'];

      // Get provider user data
      final userDoc = await _firestore
          .collection('users')
          .doc(ownerUid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final deviceTokens = List<String>.from(userData['deviceTokens'] ?? []);
      // final providerName = userData['name'] ?? 'Provider'; // Unused variable

      String title;
      String body;

      switch (status) {
        case 'approved':
          title = 'Verification Approved!';
          body = 'Congratulations! Your provider account has been verified and is now active.';
          break;
        case 'rejected':
          title = 'Verification Rejected';
          body = reason ?? 'Your provider account verification has been rejected. Please review and resubmit your documents.';
          break;
        case 'pending':
          title = 'Verification Under Review';
          body = 'Your provider account verification is currently under review by our admin team.';
          break;
        default:
          title = 'Verification Status Update';
          body = 'Your provider account verification status has been updated.';
      }

      if (deviceTokens.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: ownerUid,
          title: title,
          body: body,
          data: {
            'type': 'verification_status',
            'status': status,
            'providerId': providerId,
            'reason': reason,
            'adminName': adminName,
          },
        );
      }

      // Create in-app notification
      await _createInAppNotification(
        title: title,
        body: body,
        type: 'verification_status',
        data: {
          'providerId': providerId,
          'status': status,
          'reason': reason,
          'adminName': adminName,
        },
        targetUserId: ownerUid,
      );
    } catch (e) {
      print('Error notifying provider about verification status: $e');
    }
  }

  // Create in-app notification
  static Future<void> _createInAppNotification({
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
    String? targetRole,
    String? targetUserId,
  }) async {
    try {
      final notificationData = {
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'targetRole': targetRole,
        'targetUserId': targetUserId,
      };

      await _firestore.collection('notifications').add(notificationData);
    } catch (e) {
      print('Error creating in-app notification: $e');
    }
  }

  // Get notifications for a user
  static Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // Get notifications for a role
  static Stream<List<Map<String, dynamic>>> getRoleNotifications(String role) {
    return _firestore
        .collection('notifications')
        .where('targetRole', isEqualTo: role)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Get unread notification count
  static Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get unread notification count for role
  static Stream<int> getUnreadNotificationCountForRole(String role) {
    return _firestore
        .collection('notifications')
        .where('targetRole', isEqualTo: role)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
