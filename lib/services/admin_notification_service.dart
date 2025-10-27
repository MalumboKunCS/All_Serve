import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

class AdminNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _createInAppNotification(
        title: title,
        body: body,
        type: type,
        data: data ?? {},
        targetUserId: userId,
      );
      
      // Also send push notification if needed
      // PushNotificationService.sendToUser(userId, title, body, data);
    } catch (e) {
      AppLogger.error('Error sending admin notification to user: $e');
    }
  }

  static Future<void> sendNotificationToRole({
    required String role,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _createInAppNotification(
        title: title,
        body: body,
        type: type,
        data: data ?? {},
        targetRole: role,
      );
      
      // Also send push notification if needed
      // PushNotificationService.sendToTopic(role, title, body, data);
    } catch (e) {
      AppLogger.error('Error sending admin notification to role: $e');
    }
  }

  /// Notify admins about new provider registration
  static Future<void> notifyNewProviderRegistration({
    required String providerId,
    required String providerName,
    required String businessName,
  }) async {
    try {
      // Send notification to all admins
      await sendNotificationToRole(
        role: 'admin',
        title: 'New Provider Registration',
        body: '$providerName ($businessName) has submitted their registration for review',
        type: 'provider_verification',
        data: {
          'providerId': providerId,
          'action': 'review_required',
        },
      );
    } catch (e) {
      AppLogger.error('Error notifying admins about new provider registration: $e');
    }
  }

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
      AppLogger.error('Error creating in-app notification: $e');
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
      AppLogger.error('Error marking notification as read: $e');
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