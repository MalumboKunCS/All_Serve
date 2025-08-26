import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Send notification to a specific user (alias for sendNotification)
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? notificationType,
  }) async {
    return sendNotification(
      userId: userId,
      title: title,
      body: body,
      data: data,
      imageUrl: imageUrl,
      notificationType: notificationType,
    );
  }

  // Send notification to a specific user
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? notificationType,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        // User doesn't have FCM token, store notification in database
        await _storeNotificationInDatabase(
          userId: userId,
          title: title,
          body: body,
          data: data,
          imageUrl: imageUrl,
          notificationType: notificationType,
        );
        return;
      }

      // Send FCM notification
      await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: data,
        imageUrl: imageUrl,
      );

      // Also store in database for offline users
      await _storeNotificationInDatabase(
        userId: userId,
        title: title,
        body: body,
        data: data,
        imageUrl: imageUrl,
        notificationType: notificationType,
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
      // Fallback: store in database only
      await _storeNotificationInDatabase(
        userId: userId,
        title: title,
        body: body,
        data: data,
        imageUrl: imageUrl,
        notificationType: notificationType,
      );
    }
  }

  // Send FCM notification
  static Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      // This would typically be done through a backend server
      // For now, we'll store it in Firestore and handle it through Cloud Functions
      await _firestore.collection('fcm_notifications').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data ?? {},
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
    }
  }

  // Store notification in database
  static Future<void> _storeNotificationInDatabase({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? notificationType,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).collection('notifications').add({
          'title': title,
          'body': body,
          'data': data ?? {},
        'imageUrl': imageUrl,
        'type': notificationType ?? 'general',
        'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }
  }

  // Get user's notifications
  static Future<List<AppNotification>> getUserNotifications({
    required String userId,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
          .limit(limit);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppNotification.fromMap(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllNotificationsAsRead({
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  static Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Get unread notification count
  static Future<int> getUnreadNotificationCount({
    required String userId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      
      return querySnapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Send booking notification
  static Future<void> sendBookingNotification({
    required String providerId,
    required String customerId,
    required String bookingId,
    required String serviceName,
    required DateTime scheduledDate,
  }) async {
    await sendNotification(
      userId: providerId,
      title: 'New Booking Request',
      body: 'A customer has requested $serviceName on ${_formatDate(scheduledDate)}',
      data: {
        'type': 'new_booking',
        'bookingId': bookingId,
        'customerId': customerId,
        'serviceName': serviceName,
        'scheduledDate': scheduledDate.toIso8601String(),
      },
      notificationType: 'booking',
    );
  }

  // Send booking update notification
  static Future<void> sendBookingUpdateNotification({
    required String userId,
    required String bookingId,
    required String status,
    required String serviceName,
    DateTime? scheduledDate,
  }) async {
    String body = 'Your $serviceName booking has been $status';
    if (scheduledDate != null) {
      body += ' for ${_formatDate(scheduledDate)}';
    }

    await sendNotification(
      userId: userId,
      title: 'Booking Update',
      body: body,
      data: {
        'type': 'booking_update',
        'bookingId': bookingId,
        'status': status,
        'serviceName': serviceName,
        'scheduledDate': scheduledDate?.toIso8601String(),
      },
      notificationType: 'booking_update',
    );
  }

  // Send review request notification
  static Future<void> sendReviewRequestNotification({
    required String customerId,
    required String providerName,
    required String serviceName,
    required String bookingId,
  }) async {
    await sendNotification(
      userId: customerId,
      title: 'Review Your Service',
      body: 'How was your $serviceName experience with $providerName?',
      data: {
        'type': 'review_request',
        'providerName': providerName,
        'serviceName': serviceName,
        'bookingId': bookingId,
      },
      notificationType: 'review_request',
    );
  }

  // Send review notification
  static Future<void> sendReviewNotification({
    required String providerId,
    required String serviceName,
    required double rating,
  }) async {
    await sendNotification(
      userId: providerId,
      title: 'New Review',
      body: 'A customer left a ${rating.toStringAsFixed(1)}-star review for $serviceName',
      data: {
        'type': 'new_review',
        'serviceName': serviceName,
        'rating': rating,
      },
      notificationType: 'review',
    );
  }

  // Send payment notification
  static Future<void> sendPaymentNotification({
    required String userId,
    required String amount,
    required String serviceName,
    required String status,
  }) async {
    await sendNotification(
      userId: userId,
      title: 'Payment $status',
      body: 'Payment of \$$amount for $serviceName has been $status',
      data: {
        'type': 'payment',
        'amount': amount,
        'serviceName': serviceName,
        'status': status,
      },
      notificationType: 'payment',
    );
  }

  // Send reminder notification
  static Future<void> sendReminderNotification({
    required String userId,
    required String serviceName,
    required DateTime scheduledDate,
    required String providerName,
  }) async {
    await sendNotification(
      userId: userId,
      title: 'Service Reminder',
      body: 'Your $serviceName with $providerName is scheduled for tomorrow',
      data: {
        'type': 'reminder',
        'serviceName': serviceName,
        'scheduledDate': scheduledDate.toIso8601String(),
        'providerName': providerName,
      },
      notificationType: 'reminder',
    );
  }

  // Helper method to format date
  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Initialize FCM for current user
  static Future<void> initializeFCM() async {
    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          // Save token to user's document
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore.collection('users').doc(user.uid).update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          }
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          final user = _auth.currentUser;
          if (user != null) {
            _firestore.collection('users').doc(user.uid).update({
              'fcmToken': newToken,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? imageUrl;
  final String type;
  final bool isRead;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    this.imageUrl,
    required this.type,
    required this.isRead,
    required this.timestamp,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      data: map['data'] ?? {},
      imageUrl: map['imageUrl'],
      type: map['type'] ?? 'general',
      isRead: map['isRead'] ?? false,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'data': data,
      'imageUrl': imageUrl,
      'type': type,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

