import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';

class AppNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get notifications for a user
  static Stream<List<Notification>> getNotificationsStream(String receiverId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Notification.fromFirestore(doc)).toList();
    });
  }

  /// Get admin notifications for a user
  static Stream<List<Notification>> getAdminNotificationsStream(String receiverId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: receiverId)
        .where('type', isEqualTo: 'admin')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Notification.fromFirestore(doc)).toList();
    });
  }

  /// Get customer notifications for a user
  static Stream<List<Notification>> getCustomerNotificationsStream(String receiverId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: receiverId)
        .where('type', isEqualTo: 'customer')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Notification.fromFirestore(doc)).toList();
    });
  }

  /// Get unread notification count
  static Stream<int> getUnreadCountStream(String receiverId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: receiverId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead(String receiverId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: receiverId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Send notification to user
  static Future<void> sendNotification({
    required String receiverId,
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Clear all notifications for user
  static Future<void> clearAllNotifications(String receiverId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: receiverId)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }
}





