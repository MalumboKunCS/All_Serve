import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;

class AdminNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Notify provider about verification status change
  static Future<void> notifyProviderVerificationStatus({
    required String providerId,
    required String status, // 'approved', 'rejected', 'pending'
    String? reason,
    String? adminName,
  }) async {
    try {
      // Get provider document to find owner UID
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      if (!providerDoc.exists) return;

      final providerData = providerDoc.data()!;
      final ownerUid = providerData['ownerUid'] as String?;
      final providerName = providerData['ownerName'] as String?;

      if (ownerUid == null) return;

      // Get user document for device tokens
      final userDoc = await _firestore.collection('users').doc(ownerUid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final deviceTokens = List<String>.from(userData['deviceTokens'] ?? []);

      String title;
      String body;

      switch (status) {
        case 'approved':
          title = 'Provider Account Approved!';
          body = 'Congratulations! Your business is now verified and active.';
          break;
        case 'rejected':
          title = 'Provider Account Rejected';
          body = 'Unfortunately, your registration was rejected. Reason: ${reason ?? 'N/A'}';
          break;
        case 'pending':
          title = 'Verification Status Update';
          body = 'Your provider account verification status has been updated.';
          break;
        default:
          title = 'Verification Status Update';
          body = 'Your provider account verification status has been updated.';
      }

      // Send push notification if device tokens exist
      if (deviceTokens.isNotEmpty) {
        await shared.NotificationService.sendNotificationToUser(
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
        recipientUid: ownerUid,
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

      print('Notification sent to provider $providerName for status: $status');
    } catch (e) {
      print('Error notifying provider about verification status: $e');
    }
  }

  /// Notify admins about new provider registration
  static Future<void> notifyNewProviderRegistration({
    required String providerId,
    required String providerName,
    required String businessName,
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
          await shared.NotificationService.sendNotificationToUser(
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
        recipientUid: 'admin', // Special recipient for admin notifications
        title: 'New Provider Registration',
        body: '$providerName ($businessName) has submitted their registration for review',
        data: {
          'type': 'provider_verification',
          'providerId': providerId,
          'action': 'review_required',
        },
      );
    } catch (e) {
      print('Error notifying admins about new provider registration: $e');
    }
  }

  /// Notify admins about document updates
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
          await shared.NotificationService.sendNotificationToUser(
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

  /// Create in-app notification
  static Future<void> _createInAppNotification({
    required String recipientUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientUid': recipientUid,
        'title': title,
        'body': body,
        'data': data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating in-app notification: $e');
    }
  }
}











