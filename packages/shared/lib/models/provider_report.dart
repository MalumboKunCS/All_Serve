import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType {
  complaint,
  violation,
  qualityIssue,
  safetyConcern,
  other,
}

enum ReportStatus {
  pending,
  investigating,
  resolved,
  dismissed,
}

class ProviderReport {
  final String reportId;
  final String providerId;
  final String reportedBy; // customerId or adminId
  final String reporterName; // Name of person reporting
  final String reporterEmail; // Email of person reporting
  final ReportType reportType;
  final String title;
  final String description;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? adminNotes;
  final List<String> attachments; // URLs to attached files/images
  final String? bookingId; // Related booking if applicable
  final int priority; // 1 = Low, 2 = Medium, 3 = High, 4 = Critical

  ProviderReport({
    required this.reportId,
    required this.providerId,
    required this.reportedBy,
    required this.reporterName,
    required this.reporterEmail,
    required this.reportType,
    required this.title,
    required this.description,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.adminNotes,
    this.attachments = const [],
    this.bookingId,
    this.priority = 1,
  });

  factory ProviderReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProviderReport(
      reportId: doc.id,
      providerId: data['providerId'] ?? '',
      reportedBy: data['reportedBy'] ?? '',
      reporterName: data['reporterName'] ?? '',
      reporterEmail: data['reporterEmail'] ?? '',
      reportType: ReportType.values.firstWhere(
        (e) => e.name == data['reportType'],
        orElse: () => ReportType.other,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: ReportStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReportStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      resolvedAt: data['resolvedAt'] != null 
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      resolvedBy: data['resolvedBy'],
      adminNotes: data['adminNotes'],
      attachments: List<String>.from(data['attachments'] ?? []),
      bookingId: data['bookingId'],
      priority: data['priority'] ?? 1,
    );
  }

  factory ProviderReport.fromMap(Map<String, dynamic> data, {String? id}) {
    return ProviderReport(
      reportId: id ?? data['reportId'] ?? '',
      providerId: data['providerId'] ?? '',
      reportedBy: data['reportedBy'] ?? '',
      reporterName: data['reporterName'] ?? '',
      reporterEmail: data['reporterEmail'] ?? '',
      reportType: ReportType.values.firstWhere(
        (e) => e.name == data['reportType'],
        orElse: () => ReportType.other,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: ReportStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReportStatus.pending,
      ),
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      resolvedAt: data['resolvedAt'] != null 
          ? (data['resolvedAt'] is Timestamp 
              ? (data['resolvedAt'] as Timestamp).toDate()
              : DateTime.parse(data['resolvedAt']))
          : null,
      resolvedBy: data['resolvedBy'],
      adminNotes: data['adminNotes'],
      attachments: List<String>.from(data['attachments'] ?? []),
      bookingId: data['bookingId'],
      priority: data['priority'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'reportedBy': reportedBy,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'reportType': reportType.name,
      'title': title,
      'description': description,
      'status': status.name,
      'createdAt': createdAt,
      'resolvedAt': resolvedAt,
      'resolvedBy': resolvedBy,
      'adminNotes': adminNotes,
      'attachments': attachments,
      'bookingId': bookingId,
      'priority': priority,
    };
  }

  ProviderReport copyWith({
    String? reportId,
    String? providerId,
    String? reportedBy,
    String? reporterName,
    String? reporterEmail,
    ReportType? reportType,
    String? title,
    String? description,
    ReportStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? adminNotes,
    List<String>? attachments,
    String? bookingId,
    int? priority,
  }) {
    return ProviderReport(
      reportId: reportId ?? this.reportId,
      providerId: providerId ?? this.providerId,
      reportedBy: reportedBy ?? this.reportedBy,
      reporterName: reporterName ?? this.reporterName,
      reporterEmail: reporterEmail ?? this.reporterEmail,
      reportType: reportType ?? this.reportType,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      adminNotes: adminNotes ?? this.adminNotes,
      attachments: attachments ?? this.attachments,
      bookingId: bookingId ?? this.bookingId,
      priority: priority ?? this.priority,
    );
  }

  String get reportTypeDisplayName {
    switch (reportType) {
      case ReportType.complaint:
        return 'Customer Complaint';
      case ReportType.violation:
        return 'Policy Violation';
      case ReportType.qualityIssue:
        return 'Quality Issue';
      case ReportType.safetyConcern:
        return 'Safety Concern';
      case ReportType.other:
        return 'Other';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.investigating:
        return 'Investigating';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.dismissed:
        return 'Dismissed';
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Critical';
      default:
        return 'Low';
    }
  }

  @override
  String toString() {
    return 'ProviderReport(reportId: $reportId, providerId: $providerId, title: $title, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProviderReport && other.reportId == reportId;
  }

  @override
  int get hashCode => reportId.hashCode;
}
