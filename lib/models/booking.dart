import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:all_server/services/notification_service.dart';
import 'package:flutter/foundation.dart';

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

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Create a new booking request
  Future<String?> createBooking(Booking booking) async {
    try {
      final docRef = await _firestore.collection('bookings').add(booking.toMap());
      
      // Send notification to provider
      await _notificationService.sendNotificationToUser(
        userId: booking.providerId,
        title: 'New Booking Request',
        body: 'You have a new booking request for ${booking.serviceType}',
        data: {
          'type': 'booking_request',
          'bookingId': docRef.id,
        },
      );

      return docRef.id;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error creating booking: $e');
      return null;
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
    String? providerNotes,
    double? finalPrice,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (providerNotes != null) updateData['providerNotes'] = providerNotes;
      if (finalPrice != null) updateData['finalPrice'] = finalPrice;
      
      if (status == BookingStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('bookings').doc(bookingId).update(updateData);

      // Get booking details for notification
      final booking = await getBooking(bookingId);
      if (booking != null) {
        String notificationTitle = '';
        String notificationBody = '';

        switch (status) {
          case BookingStatus.accepted:
            notificationTitle = 'Booking Accepted';
            notificationBody = 'Your booking request has been accepted!';
            break;
          case BookingStatus.rejected:
            notificationTitle = 'Booking Rejected';
            notificationBody = 'Your booking request has been rejected.';
            break;
          case BookingStatus.completed:
            notificationTitle = 'Service Completed';
            notificationBody = 'Your service has been completed. Please rate the provider.';
            break;
          default:
            notificationTitle = 'Booking Updated';
            notificationBody = 'Your booking status has been updated.';
        }

        // Send notification to user
        await _notificationService.sendNotificationToUser(
          userId: booking.userId,
          title: notificationTitle,
          body: notificationBody,
          data: {
            'type': 'booking_update',
            'bookingId': bookingId,
            'status': status.name,
          },
        );
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  // Get single booking
  Future<Booking?> getBooking(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (doc.exists) {
        return Booking.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting booking: $e');
      return null;
    }
  }

  // Get user bookings
  Stream<List<Booking>> getUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Booking.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get provider bookings
  Stream<List<Booking>> getProviderBookings(String providerId) {
    return _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Booking.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get pending bookings for provider
  Stream<List<Booking>> getPendingBookings(String providerId) {
    return _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .where('status', isEqualTo: BookingStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Booking.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}
