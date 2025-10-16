import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String announcementId;
  final String title;
  final String message;
  final String createdBy; // admin uid
  final DateTime createdAt;
  final String audience; // "all" | "customers" | "providers" | "admins"
  final List<String> targetCategories; // empty for all categories
  final bool isActive;
  final DateTime? expiresAt;
  final int sentCount; // number of recipients
  final String priority; // "low" | "medium" | "high" | "urgent"
  final String type; // "info" | "warning" | "promotion" | "maintenance" | "update"

  Announcement({
    required this.announcementId,
    required this.title,
    required this.message,
    required this.createdBy,
    required this.createdAt,
    required this.audience,
    this.targetCategories = const [],
    this.isActive = true,
    this.expiresAt,
    this.sentCount = 0,
    this.priority = 'medium',
    this.type = 'info',
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Announcement(
      announcementId: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      audience: data['audience'] ?? 'all',
      targetCategories: List<String>.from(data['targetCategories'] ?? []),
      isActive: data['isActive'] ?? true,
      expiresAt: data['expiresAt'] != null 
        ? (data['expiresAt'] as Timestamp).toDate() 
        : null,
      sentCount: data['sentCount'] ?? 0,
      priority: data['priority'] ?? 'medium',
      type: data['type'] ?? 'info',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'audience': audience,
      'targetCategories': targetCategories,
      'isActive': isActive,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'sentCount': sentCount,
      'priority': priority,
      'type': type,
    };
  }

  Announcement copyWith({
    String? title,
    String? message,
    String? audience,
    List<String>? targetCategories,
    bool? isActive,
    DateTime? expiresAt,
    int? sentCount,
    String? priority,
    String? type,
  }) {
    return Announcement(
      announcementId: announcementId,
      title: title ?? this.title,
      message: message ?? this.message,
      createdBy: createdBy,
      createdAt: createdAt,
      audience: audience ?? this.audience,
      targetCategories: targetCategories ?? this.targetCategories,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      sentCount: sentCount ?? this.sentCount,
      priority: priority ?? this.priority,
      type: type ?? this.type,
    );
  }

  // Status checkers
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get shouldDisplay => isActive && !isExpired;

  // Audience checkers
  bool get isForAll => audience == 'all';
  bool get isForCustomers => audience == 'customers' || audience == 'all';
  bool get isForProviders => audience == 'providers' || audience == 'all';
  bool get isForAdmins => audience == 'admins' || audience == 'all';

  // Category targeting
  bool get hasTargetCategories => targetCategories.isNotEmpty;
  bool isForCategory(String categoryId) {
    return !hasTargetCategories || targetCategories.contains(categoryId);
  }

  // Priority and type getters
  bool get isUrgent => priority == 'urgent';
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
  bool get isLowPriority => priority == 'low';

  bool get isWarning => type == 'warning';
  bool get isPromotion => type == 'promotion';
  bool get isMaintenance => type == 'maintenance';
  bool get isUpdate => type == 'update';

  // Display formatting
  String get formattedCreatedAt {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedExpiresAt {
    if (expiresAt == null) return 'No expiration';
    return '${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year} ${expiresAt!.hour.toString().padLeft(2, '0')}:${expiresAt!.minute.toString().padLeft(2, '0')}';
  }

  String get audienceDisplayText {
    switch (audience) {
      case 'all':
        return 'All Users';
      case 'customers':
        return 'Customers';
      case 'providers':
        return 'Providers';
      case 'admins':
        return 'Admins';
      default:
        return audience.toUpperCase();
    }
  }

  String get priorityDisplayText {
    switch (priority) {
      case 'urgent':
        return 'URGENT';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority.toUpperCase();
    }
  }

  String get typeDisplayText {
    switch (type) {
      case 'info':
        return 'Information';
      case 'warning':
        return 'Warning';
      case 'promotion':
        return 'Promotion';
      case 'maintenance':
        return 'Maintenance';
      case 'update':
        return 'Update';
      default:
        return type.toUpperCase();
    }
  }

  // Status display
  String get statusText {
    if (isExpired) return 'Expired';
    if (!isActive) return 'Inactive';
    return 'Active';
  }

  // Time calculations
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return 'Expired';
    
    final difference = expiresAt!.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} remaining';
    } else {
      return 'Expires soon';
    }
  }
}












