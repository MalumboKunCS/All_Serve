import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  pendingCustomerConfirmation,
  completed,
  cancelled,
  rescheduled,
}

enum PaymentStatus {
  unpaid,
  paid,
  refunded,
  failed,
  pending,
}

class Booking {
  final String bookingId;
  final String customerId;
  final String providerId;
  final String serviceId;
  final String serviceTitle;
  final String serviceCategory;
  final double estimatedPrice;
  final double finalPrice;
  final int durationMinutes;
  final Map<String, dynamic> address; // {address, lat, lng, city, country}
  final DateTime scheduledAt;
  final DateTime requestedAt;
  final BookingStatus status;
  final String? customerNotes;
  final String? providerNotes;
  final String? cancellationReason;
  final String? rescheduleReason;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? customerData;
  final Map<String, dynamic>? providerData;
  final Map<String, dynamic>? serviceData;
  final bool isUrgent;
  final String? timeSlot; // e.g., "09:00-10:00"
  final List<String> specialRequirements;
  
  // Customer contact information
  final String? customerFullName;
  final String? customerPhoneNumber;
  final String? customerEmailAddress;
  final String? additionalNotes;
  
  // Review tracking
  final bool hasReview;
  final String? reviewId;
  
  // Payment tracking
  final PaymentStatus? paymentStatus;
  final String? paymentId;
  final String? paymentMethod;
  
  // Timezone support
  final String? timezone;

  Booking({
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.serviceTitle,
    required this.serviceCategory,
    required this.estimatedPrice,
    this.finalPrice = 0.0,
    required this.durationMinutes,
    required this.address,
    required this.scheduledAt,
    required this.requestedAt,
    required this.status,
    this.customerNotes,
    this.providerNotes,
    this.cancellationReason,
    this.rescheduleReason,
    this.completedAt,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
    this.customerData,
    this.providerData,
    this.serviceData,
    this.isUrgent = false,
    this.timeSlot,
    this.specialRequirements = const [],
    this.customerFullName,
    this.customerPhoneNumber,
    this.customerEmailAddress,
    this.additionalNotes,
    this.hasReview = false,
    this.reviewId,
    this.paymentStatus,
    this.paymentId,
    this.paymentMethod,
    this.timezone,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      bookingId: doc.id,
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      serviceTitle: data['serviceTitle'] ?? '',
      serviceCategory: data['serviceCategory'] ?? '',
      estimatedPrice: (data['estimatedPrice'] ?? 0.0).toDouble(),
      finalPrice: (data['finalPrice'] ?? 0.0).toDouble(),
      durationMinutes: data['durationMinutes'] ?? 0,
      address: Map<String, dynamic>.from(data['address'] ?? {}),
      scheduledAt: data['scheduledAt'] is Timestamp 
          ? (data['scheduledAt'] as Timestamp).toDate()
          : DateTime.parse(data['scheduledAt'] ?? DateTime.now().toIso8601String()),
      requestedAt: data['requestedAt'] is Timestamp 
          ? (data['requestedAt'] as Timestamp).toDate()
          : DateTime.parse(data['requestedAt'] ?? DateTime.now().toIso8601String()),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => BookingStatus.pending,
      ),
      customerNotes: data['customerNotes'],
      providerNotes: data['providerNotes'],
      cancellationReason: data['cancellationReason'],
      rescheduleReason: data['rescheduleReason'],
      completedAt: data['completedAt'] is Timestamp 
          ? (data['completedAt'] as Timestamp).toDate()
          : data['completedAt'] != null 
              ? DateTime.parse(data['completedAt'])
              : null,
      cancelledAt: data['cancelledAt'] is Timestamp 
          ? (data['cancelledAt'] as Timestamp).toDate()
          : data['cancelledAt'] != null 
              ? DateTime.parse(data['cancelledAt'])
              : null,
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(data['updatedAt'] ?? DateTime.now().toIso8601String()),
      customerData: data['customerData'] != null 
          ? Map<String, dynamic>.from(data['customerData'])
          : null,
      providerData: data['providerData'] != null 
          ? Map<String, dynamic>.from(data['providerData'])
          : null,
      serviceData: data['serviceData'] != null 
          ? Map<String, dynamic>.from(data['serviceData'])
          : null,
      isUrgent: data['isUrgent'] ?? false,
      timeSlot: data['timeSlot'],
      specialRequirements: List<String>.from(data['specialRequirements'] ?? []),
      customerFullName: data['customerFullName'],
      customerPhoneNumber: data['customerPhoneNumber'],
      customerEmailAddress: data['customerEmailAddress'],
      additionalNotes: data['additionalNotes'],
      hasReview: data['hasReview'] ?? false,
      reviewId: data['reviewId'],
      paymentStatus: data['paymentStatus'] != null
          ? PaymentStatus.values.firstWhere(
              (e) => e.name == data['paymentStatus'],
              orElse: () => PaymentStatus.unpaid,
            )
          : PaymentStatus.unpaid,
      paymentId: data['paymentId'],
      paymentMethod: data['paymentMethod'],
      timezone: data['timezone'],
    );
  }

  factory Booking.fromMap(Map<String, dynamic> data, {String? id}) {
    return Booking(
      bookingId: id ?? data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      serviceTitle: data['serviceTitle'] ?? '',
      serviceCategory: data['serviceCategory'] ?? '',
      estimatedPrice: (data['estimatedPrice'] ?? 0.0).toDouble(),
      finalPrice: (data['finalPrice'] ?? 0.0).toDouble(),
      durationMinutes: data['durationMinutes'] ?? 0,
      address: Map<String, dynamic>.from(data['address'] ?? {}),
      scheduledAt: data['scheduledAt'] is Timestamp 
          ? (data['scheduledAt'] as Timestamp).toDate()
          : DateTime.parse(data['scheduledAt'] ?? DateTime.now().toIso8601String()),
      requestedAt: data['requestedAt'] is Timestamp 
          ? (data['requestedAt'] as Timestamp).toDate()
          : DateTime.parse(data['requestedAt'] ?? DateTime.now().toIso8601String()),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => BookingStatus.pending,
      ),
      customerNotes: data['customerNotes'],
      providerNotes: data['providerNotes'],
      cancellationReason: data['cancellationReason'],
      rescheduleReason: data['rescheduleReason'],
      completedAt: data['completedAt'] is Timestamp 
          ? (data['completedAt'] as Timestamp).toDate()
          : data['completedAt'] != null 
              ? DateTime.parse(data['completedAt'])
              : null,
      cancelledAt: data['cancelledAt'] is Timestamp 
          ? (data['cancelledAt'] as Timestamp).toDate()
          : data['cancelledAt'] != null 
              ? DateTime.parse(data['cancelledAt'])
              : null,
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(data['updatedAt'] ?? DateTime.now().toIso8601String()),
      customerData: data['customerData'] != null 
          ? Map<String, dynamic>.from(data['customerData'])
          : null,
      providerData: data['providerData'] != null 
          ? Map<String, dynamic>.from(data['providerData'])
          : null,
      serviceData: data['serviceData'] != null 
          ? Map<String, dynamic>.from(data['serviceData'])
          : null,
      isUrgent: data['isUrgent'] ?? false,
      timeSlot: data['timeSlot'],
      specialRequirements: List<String>.from(data['specialRequirements'] ?? []),
      customerFullName: data['customerFullName'],
      customerPhoneNumber: data['customerPhoneNumber'],
      customerEmailAddress: data['customerEmailAddress'],
      additionalNotes: data['additionalNotes'],
      hasReview: data['hasReview'] ?? false,
      reviewId: data['reviewId'],
      paymentStatus: data['paymentStatus'] != null
          ? PaymentStatus.values.firstWhere(
              (e) => e.name == data['paymentStatus'],
              orElse: () => PaymentStatus.unpaid,
            )
          : PaymentStatus.unpaid,
      paymentId: data['paymentId'],
      paymentMethod: data['paymentMethod'],
      timezone: data['timezone'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'providerId': providerId,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'serviceCategory': serviceCategory,
      'estimatedPrice': estimatedPrice,
      'finalPrice': finalPrice,
      'durationMinutes': durationMinutes,
      'address': address,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status.name,
      'customerNotes': customerNotes,
      'providerNotes': providerNotes,
      'cancellationReason': cancellationReason,
      'rescheduleReason': rescheduleReason,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'customerData': customerData,
      'providerData': providerData,
      'serviceData': serviceData,
      'isUrgent': isUrgent,
      'timeSlot': timeSlot,
      'specialRequirements': specialRequirements,
      'customerFullName': customerFullName,
      'customerPhoneNumber': customerPhoneNumber,
      'customerEmailAddress': customerEmailAddress,
      'additionalNotes': additionalNotes,
      'hasReview': hasReview,
      'reviewId': reviewId,
      'paymentStatus': paymentStatus?.name,
      'paymentId': paymentId,
      'paymentMethod': paymentMethod,
      'timezone': timezone,
    };
  }

  Booking copyWith({
    String? bookingId,
    String? customerId,
    String? providerId,
    String? serviceId,
    String? serviceTitle,
    String? serviceCategory,
    double? estimatedPrice,
    double? finalPrice,
    int? durationMinutes,
    Map<String, dynamic>? address,
    DateTime? scheduledAt,
    DateTime? requestedAt,
    BookingStatus? status,
    String? customerNotes,
    String? providerNotes,
    String? cancellationReason,
    String? rescheduleReason,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? customerData,
    Map<String, dynamic>? providerData,
    Map<String, dynamic>? serviceData,
    bool? isUrgent,
    String? timeSlot,
    List<String>? specialRequirements,
    String? customerFullName,
    String? customerPhoneNumber,
    String? customerEmailAddress,
    String? additionalNotes,
    bool? hasReview,
    String? reviewId,
    PaymentStatus? paymentStatus,
    String? paymentId,
    String? paymentMethod,
    String? timezone,
  }) {
    return Booking(
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      address: address ?? this.address,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      customerNotes: customerNotes ?? this.customerNotes,
      providerNotes: providerNotes ?? this.providerNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      rescheduleReason: rescheduleReason ?? this.rescheduleReason,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerData: customerData ?? this.customerData,
      providerData: providerData ?? this.providerData,
      serviceData: serviceData ?? this.serviceData,
      isUrgent: isUrgent ?? this.isUrgent,
      timeSlot: timeSlot ?? this.timeSlot,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      customerFullName: customerFullName ?? this.customerFullName,
      customerPhoneNumber: customerPhoneNumber ?? this.customerPhoneNumber,
      customerEmailAddress: customerEmailAddress ?? this.customerEmailAddress,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      hasReview: hasReview ?? this.hasReview,
      reviewId: reviewId ?? this.reviewId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timezone: timezone ?? this.timezone,
    );
  }

  // Status check methods
  bool get canBeCancelled => status == BookingStatus.pending || status == BookingStatus.accepted;
  bool get canBeRescheduled => status == BookingStatus.pending || status == BookingStatus.accepted;
  bool get canBeAccepted => status == BookingStatus.pending;
  bool get canBeRejected => status == BookingStatus.pending;
  bool get canBeCompleted => status == BookingStatus.accepted || status == BookingStatus.inProgress;
  bool get canBeStarted => status == BookingStatus.accepted;
  bool get canBeConfirmedByCustomer => status == BookingStatus.pendingCustomerConfirmation;
  bool get isPendingCustomerConfirmation => status == BookingStatus.pendingCustomerConfirmation;
  
  bool get isCompleted => status == BookingStatus.completed;
  bool get isCancelled => status == BookingStatus.cancelled;
  bool get isRejected => status == BookingStatus.rejected;
  bool get isPending => status == BookingStatus.pending;
  bool get isAccepted => status == BookingStatus.accepted;
  bool get isInProgress => status == BookingStatus.inProgress;
  bool get isRescheduled => status == BookingStatus.rescheduled;
  
  // Payment check methods
  bool get isPaymentRequired => paymentStatus != null && paymentStatus != PaymentStatus.paid;
  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isPaymentPending => paymentStatus == PaymentStatus.pending;
  bool get isPaymentFailed => paymentStatus == PaymentStatus.failed;
  bool get canBeRefunded => isPaid && (isCompleted || isCancelled);
  
  // Review eligibility
  bool get canBeReviewed => isCompleted && !hasReview;
  bool get isEligibleForReview {
    if (!isCompleted || hasReview) return false;
    if (completedAt == null) return false;
    // Allow reviews within 30 days of completion
    final reviewDeadline = completedAt!.add(const Duration(days: 30));
    return DateTime.now().isBefore(reviewDeadline);
  }

  // Utility methods
  String get statusDisplayName {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.pendingCustomerConfirmation:
        return 'Pending Confirmation';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.rescheduled:
        return 'Rescheduled';
    }
  }

  String get formattedScheduledDate {
    return '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year}';
  }

  String get formattedScheduledTime {
    return '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
  }

  Duration get timeUntilScheduled {
    return scheduledAt.difference(DateTime.now());
  }

  bool get isOverdue {
    return status == BookingStatus.accepted && 
           scheduledAt.isBefore(DateTime.now()) && 
           !isCompleted;
  }

  double get totalPrice {
    return finalPrice > 0 ? finalPrice : estimatedPrice;
  }
}
