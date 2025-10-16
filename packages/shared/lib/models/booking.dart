import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String bookingId;
  final String customerId;
  final String providerId;
  final String serviceId;
  final Map<String, dynamic> address; // {address, lat, lng}
  final DateTime scheduledAt;
  final DateTime requestedAt;
  final String status; // "requested" | "accepted" | "rejected" | "completed" | "cancelled"
  final String? notes;
  final DateTime createdAt;

  Booking({
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.address,
    required this.scheduledAt,
    required this.requestedAt,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      bookingId: doc.id,
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      address: Map<String, dynamic>.from(data['address'] ?? {}),
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'requested',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  factory Booking.fromMap(Map<String, dynamic> data, {String? id}) {
    return Booking(
      bookingId: id ?? data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      address: Map<String, dynamic>.from(data['address'] ?? {}),
      scheduledAt: data['scheduledAt'] is Timestamp 
          ? (data['scheduledAt'] as Timestamp).toDate()
          : DateTime.parse(data['scheduledAt'] ?? DateTime.now().toIso8601String()),
      requestedAt: data['requestedAt'] is Timestamp 
          ? (data['requestedAt'] as Timestamp).toDate()
          : DateTime.parse(data['requestedAt'] ?? DateTime.now().toIso8601String()),
      status: data['status'] ?? 'requested',
      notes: data['notes'],
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'providerId': providerId,
      'serviceId': serviceId,
      'address': address,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Booking copyWith({
    String? status,
    String? notes,
  }) {
    return Booking(
      bookingId: bookingId,
      customerId: customerId,
      providerId: providerId,
      serviceId: serviceId,
      address: address,
      scheduledAt: scheduledAt,
      requestedAt: requestedAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  bool get canBeCancelled => status == 'requested' || status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  bool get isRequested => status == 'requested';
  bool get isAccepted => status == 'accepted';
}












