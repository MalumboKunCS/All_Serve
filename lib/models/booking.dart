import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  completed,
  cancelled,
}

class Booking {
  final String id;
  final String userId;
  final String providerId;
  final String serviceType;
  final String? serviceDescription;
  final DateTime requestedDate;
  final String? timeSlot;
  final BookingStatus status;
  final double? estimatedPrice;
  final double? finalPrice;
  final String? userNotes;
  final String? providerNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? userAddress;
  final Map<String, double>? location; // lat, lng

  Booking({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.serviceType,
    this.serviceDescription,
    required this.requestedDate,
    this.timeSlot,
    required this.status,
    this.estimatedPrice,
    this.finalPrice,
    this.userNotes,
    this.providerNotes,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.userAddress,
    this.location,
  });

  factory Booking.fromMap(Map<String, dynamic> data, String id) {
    return Booking(
      id: id,
      userId: data['userId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceType: data['serviceType'] ?? '',
      serviceDescription: data['serviceDescription'],
      requestedDate: (data['requestedDate'] as Timestamp).toDate(),
      timeSlot: data['timeSlot'],
      status: BookingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => BookingStatus.pending,
      ),
      estimatedPrice: data['estimatedPrice']?.toDouble(),
      finalPrice: data['finalPrice']?.toDouble(),
      userNotes: data['userNotes'],
      providerNotes: data['providerNotes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      userAddress: data['userAddress'],
      location: data['location'] != null 
          ? Map<String, double>.from(data['location']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'providerId': providerId,
      'serviceType': serviceType,
      'serviceDescription': serviceDescription,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'timeSlot': timeSlot,
      'status': status.name,
      'estimatedPrice': estimatedPrice,
      'finalPrice': finalPrice,
      'userNotes': userNotes,
      'providerNotes': providerNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'userAddress': userAddress,
      'location': location,
    };
  }

  Booking copyWith({
    BookingStatus? status,
    double? finalPrice,
    String? providerNotes,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Booking(
      id: id,
      userId: userId,
      providerId: providerId,
      serviceType: serviceType,
      serviceDescription: serviceDescription,
      requestedDate: requestedDate,
      timeSlot: timeSlot,
      status: status ?? this.status,
      estimatedPrice: estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      userNotes: userNotes,
      providerNotes: providerNotes ?? this.providerNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      userAddress: userAddress,
      location: location,
    );
  }
}
