import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuditLog {
  final String logId;
  final String actorUid;
  final String action;
  final Map<String, dynamic> detail;
  final DateTime timestamp;

  AdminAuditLog({
    required this.logId,
    required this.actorUid,
    required this.action,
    required this.detail,
    required this.timestamp,
  });

  factory AdminAuditLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AdminAuditLog(
      logId: doc.id,
      actorUid: data['actorUid'] ?? '',
      action: data['action'] ?? '',
      detail: Map<String, dynamic>.from(data['detail'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'actorUid': actorUid,
      'action': action,
      'detail': detail,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Factory constructors for common actions
  factory AdminAuditLog.providerApproved({
    required String actorUid,
    required String providerId,
    required String businessName,
  }) {
    return AdminAuditLog(
      logId: '',
      actorUid: actorUid,
      action: 'PROVIDER_APPROVED',
      detail: {
        'providerId': providerId,
        'businessName': businessName,
      },
      timestamp: DateTime.now(),
    );
  }

  factory AdminAuditLog.providerRejected({
    required String actorUid,
    required String providerId,
    required String businessName,
    required String reason,
  }) {
    return AdminAuditLog(
      logId: '',
      actorUid: actorUid,
      action: 'PROVIDER_REJECTED',
      detail: {
        'providerId': providerId,
        'businessName': businessName,
        'reason': reason,
      },
      timestamp: DateTime.now(),
    );
  }

  factory AdminAuditLog.providerSuspended({
    required String actorUid,
    required String providerId,
    required String businessName,
    required String reason,
  }) {
    return AdminAuditLog(
      logId: '',
      actorUid: actorUid,
      action: 'PROVIDER_SUSPENDED',
      detail: {
        'providerId': providerId,
        'businessName': businessName,
        'reason': reason,
      },
      timestamp: DateTime.now(),
    );
  }

  factory AdminAuditLog.reviewFlagged({
    required String actorUid,
    required String reviewId,
    required String reason,
  }) {
    return AdminAuditLog(
      logId: '',
      actorUid: actorUid,
      action: 'REVIEW_FLAGGED',
      detail: {
        'reviewId': reviewId,
        'reason': reason,
      },
      timestamp: DateTime.now(),
    );
  }

  factory AdminAuditLog.reviewRemoved({
    required String actorUid,
    required String reviewId,
    required String reason,
  }) {
    return AdminAuditLog(
      logId: '',
      actorUid: actorUid,
      action: 'REVIEW_REMOVED',
      detail: {
        'reviewId': reviewId,
        'reason': reason,
      },
      timestamp: DateTime.now(),
    );
  }

  factory AdminAuditLog.announcementSent({
    required String actorUid,
    required String title,
    required String audience,
    required int recipientCount,
  }) {
    return AdminAuditLog(
      logId: '',
      actorUid: actorUid,
      action: 'ANNOUNCEMENT_SENT',
      detail: {
        'title': title,
        'audience': audience,
        'recipientCount': recipientCount,
      },
      timestamp: DateTime.now(),
    );
  }

  // Getters for common fields
  String get actionDescription {
    switch (action) {
      case 'PROVIDER_APPROVED':
        return 'Approved provider ${detail['businessName']}';
      case 'PROVIDER_REJECTED':
        return 'Rejected provider ${detail['businessName']}';
      case 'PROVIDER_SUSPENDED':
        return 'Suspended provider ${detail['businessName']}';
      case 'REVIEW_FLAGGED':
        return 'Flagged review for moderation';
      case 'REVIEW_REMOVED':
        return 'Removed review';
      case 'ANNOUNCEMENT_SENT':
        return 'Sent announcement "${detail['title']}" to ${detail['audience']}';
      default:
        return action;
    }
  }

  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

