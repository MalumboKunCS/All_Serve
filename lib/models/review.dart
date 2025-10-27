import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String reviewId;
  final String bookingId;
  final String customerId;
  final String providerId;
  final double rating;
  final String? title; // Optional review title
  final String comment;
  final DateTime createdAt;
  final bool isFlagged;
  final String? flagReason;
  final bool isVisible; // For admin moderation
  final List<String> helpfulVotes;
  final String? customerName; // For display purposes
  final String? customerAvatar; // For display purposes
  final DateTime? updatedAt;

  Review({
    required this.reviewId,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.rating,
    this.title,
    required this.comment,
    required this.createdAt,
    this.isFlagged = false,
    this.flagReason,
    this.isVisible = true,
    this.helpfulVotes = const [],
    this.customerName,
    this.customerAvatar,
    this.updatedAt,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Review(
      reviewId: doc.id,
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      title: data['title'],
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isFlagged: data['isFlagged'] ?? false,
      flagReason: data['flagReason'],
      isVisible: data['isVisible'] ?? true,
      helpfulVotes: List<String>.from(data['helpfulVotes'] ?? []),
      customerName: data['customerName'],
      customerAvatar: data['customerAvatar'],
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  factory Review.fromMap(Map<String, dynamic> data, {String? id}) {
    return Review(
      reviewId: id ?? data['reviewId'] ?? '',
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      title: data['title'],
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      isFlagged: data['isFlagged'] ?? false,
      flagReason: data['flagReason'],
      isVisible: data['isVisible'] ?? true,
      helpfulVotes: List<String>.from(data['helpfulVotes'] ?? []),
      customerName: data['customerName'],
      customerAvatar: data['customerAvatar'],
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate()
          : data['updatedAt'] != null 
              ? DateTime.parse(data['updatedAt'])
              : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'rating': rating,
      'title': title,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'isVisible': isVisible,
      'helpfulVotes': helpfulVotes,
      'customerName': customerName,
      'customerAvatar': customerAvatar,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Review copyWith({
    String? bookingId,
    String? customerId,
    String? providerId,
    double? rating,
    String? title,
    String? comment,
    DateTime? createdAt,
    bool? isFlagged,
    String? flagReason,
    bool? isVisible,
    List<String>? helpfulVotes,
    String? customerName,
    String? customerAvatar,
    DateTime? updatedAt,
  }) {
    return Review(
      reviewId: reviewId,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      isVisible: isVisible ?? this.isVisible,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}