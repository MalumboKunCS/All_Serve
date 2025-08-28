import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationQueue {
  final String queueId;
  final String providerId;
  final String ownerUid;
  final DateTime submittedAt;
  final String status; // "pending" | "approved" | "rejected"
  final String? adminNotes;
  final Map<String, String> docs; // map of storage URLs {nrcUrl, businessLicenseUrl, etc.}
  final String? reviewedBy; // admin uid who reviewed
  final DateTime? reviewedAt;

  VerificationQueue({
    required this.queueId,
    required this.providerId,
    required this.ownerUid,
    required this.submittedAt,
    this.status = 'pending',
    this.adminNotes,
    required this.docs,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory VerificationQueue.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return VerificationQueue(
      queueId: doc.id,
      providerId: data['providerId'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      adminNotes: data['adminNotes'],
      docs: Map<String, String>.from(data['docs'] ?? {}),
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt'] != null 
        ? (data['reviewedAt'] as Timestamp).toDate() 
        : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'ownerUid': ownerUid,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status,
      'adminNotes': adminNotes,
      'docs': docs,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }

  VerificationQueue copyWith({
    String? status,
    String? adminNotes,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return VerificationQueue(
      queueId: queueId,
      providerId: providerId,
      ownerUid: ownerUid,
      submittedAt: submittedAt,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      docs: docs,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  // Status checkers
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  // Document checkers
  bool get hasNRC => docs.containsKey('nrcUrl') && docs['nrcUrl']!.isNotEmpty;
  bool get hasBusinessLicense => docs.containsKey('businessLicenseUrl') && docs['businessLicenseUrl']!.isNotEmpty;
  bool get hasCertificates => docs.containsKey('certificatesUrl') && docs['certificatesUrl']!.isNotEmpty;
  
  List<String> get missingDocuments {
    List<String> missing = [];
    if (!hasNRC) missing.add('National Registration Card');
    if (!hasBusinessLicense) missing.add('Business License');
    return missing;
  }

  bool get hasAllRequiredDocuments => missingDocuments.isEmpty;

  // Time calculations
  int get daysSinceSubmission {
    return DateTime.now().difference(submittedAt).inDays;
  }

  String get submissionTimeAgo {
    final now = DateTime.now();
    final difference = now.difference(submittedAt);
    
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

  String get formattedSubmittedAt {
    return '${submittedAt.day}/${submittedAt.month}/${submittedAt.year} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedReviewedAt {
    if (reviewedAt == null) return 'Not reviewed';
    return '${reviewedAt!.day}/${reviewedAt!.month}/${reviewedAt!.year} ${reviewedAt!.hour.toString().padLeft(2, '0')}:${reviewedAt!.minute.toString().padLeft(2, '0')}';
  }

  // Priority scoring for admin queue ordering
  int get priorityScore {
    int score = 0;
    
    // Higher priority for older submissions
    score += daysSinceSubmission * 10;
    
    // Higher priority if all documents are provided
    if (hasAllRequiredDocuments) score += 50;
    
    // Lower priority if missing documents
    score -= missingDocuments.length * 20;
    
    return score;
  }
}

