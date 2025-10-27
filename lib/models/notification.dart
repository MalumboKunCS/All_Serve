import 'package:cloud_firestore/cloud_firestore.dart';

class Notification {
  final String notificationId;
  final String type; // "admin" | "customer"
  final String title;
  final String message;
  final String receiverId;
  final DateTime timestamp;
  final bool isRead;

  Notification({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.message,
    required this.receiverId,
    required this.timestamp,
    this.isRead = false,
  });

  factory Notification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Notification(
      notificationId: doc.id,
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      receiverId: data['receiverId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  factory Notification.fromMap(Map<String, dynamic> data, {String? id}) {
    return Notification(
      notificationId: id ?? data['notificationId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      receiverId: data['receiverId'] ?? '',
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'title': title,
      'message': message,
      'receiverId': receiverId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  Notification copyWith({
    String? type,
    String? title,
    String? message,
    String? receiverId,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return Notification(
      notificationId: notificationId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      receiverId: receiverId ?? this.receiverId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String get typeDisplayText {
    switch (type) {
      case 'admin':
        return 'Admin';
      case 'customer':
        return 'Customer';
      default:
        return 'System';
    }
  }
}






