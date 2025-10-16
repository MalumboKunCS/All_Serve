import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String reviewId;
  final String bookingId;
  final String customerId;
  final String providerId;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final bool flagged;
  final String? flagReason;
  final List<String> helpfulVotes;

  Review({
    required this.reviewId,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.flagged = false,
    this.flagReason,
    this.helpfulVotes = const [],
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Review(
      reviewId: doc.id,
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      flagged: data['flagged'] ?? false,
      flagReason: data['flagReason'],
      helpfulVotes: List<String>.from(data['helpfulVotes'] ?? []),
    );
  }

  factory Review.fromMap(Map<String, dynamic> data, {String? id}) {
    return Review(
      reviewId: id ?? data['reviewId'] ?? '',
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      flagged: data['flagged'] ?? false,
      flagReason: data['flagReason'],
      helpfulVotes: List<String>.from(data['helpfulVotes'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'flagged': flagged,
      'flagReason': flagReason,
      'helpfulVotes': helpfulVotes,
    };
  }

  Review copyWith({
    String? bookingId,
    String? customerId,
    String? providerId,
    double? rating,
    String? comment,
    DateTime? createdAt,
    bool? flagged,
    String? flagReason,
    List<String>? helpfulVotes,
  }) {
    return Review(
      reviewId: reviewId,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      flagged: flagged ?? this.flagged,
      flagReason: flagReason ?? this.flagReason,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
    );
  }
}












