import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';
import 'notification_service.dart';

enum BookingStatus { pending, accepted, inProgress, completed, cancelled, rejected }

class BookingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Create a new booking
  static Future<String?> createBooking({
    required String providerId,
    required String customerId,
    required String serviceType,
    required DateTime requestedDate,
    required String serviceDescription,
    required double estimatedPrice,
    String? userNotes,
    Map<String, double>? location,
    String? timeSlot,
  }) async {
    try {
      // Check if provider is available
      bool isAvailable = await _checkProviderAvailability(
        providerId,
        requestedDate,
      );
      
      if (!isAvailable) {
        throw Exception('Provider is not available at the selected time');
      }
      
      // Create booking document
      DocumentReference bookingRef = await _firestore.collection('bookings').add({
        'providerId': providerId,
        'customerId': customerId,
        'serviceType': serviceType,
        'requestedDate': Timestamp.fromDate(requestedDate),
        'serviceDescription': serviceDescription,
        'estimatedPrice': estimatedPrice,
        'userNotes': userNotes,
        'location': location,
        'timeSlot': timeSlot,
        'status': BookingStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'rating': null,
        'review': null,
        'completedAt': null,
        'providerNotes': null,
      });
      
      // Send notification to provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'New Booking Request',
        body: 'You have a new booking request from a customer',
        data: {
          'type': 'new_booking',
          'bookingId': bookingRef.id,
        },
      );
      
      return bookingRef.id;
    } catch (e) {
      rethrow;
    }
  }
  
  // Get bookings for a user (customer or provider)
  static Future<List<Booking>> getUserBookings({
    required String userId,
    required UserType userType,
    BookingStatus? status,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection('bookings');
      
      if (userType == UserType.customer) {
        query = query.where('customerId', isEqualTo: userId);
      } else {
        query = query.where('providerId', isEqualTo: userId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      
      query = query.orderBy('scheduledDate', descending: true).limit(limit);
      
      QuerySnapshot snapshot = await query.get();
      
      List<Booking> bookings = [];
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Get additional data
        if (userType == UserType.customer) {
          data['provider'] = await _getProviderData(data['providerId']);
        } else {
          data['customer'] = await _getCustomerData(data['customerId']);
        }
        
        data['service'] = await _getServiceData(data['serviceId']);
        
        bookings.add(Booking.fromMap(data, id: doc.id));
      }
      
      return bookings;
    } catch (e) {
      return [];
    }
  }
  
  // Update booking status
  static Future<bool> updateBookingStatus({
    required String bookingId,
    required BookingStatus newStatus,
    String? notes,
    String? cancellationReason,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (notes != null) {
        updateData['providerNotes'] = notes;
      }
      
      if (cancellationReason != null) {
        updateData['cancellationReason'] = cancellationReason;
      }
      
      if (newStatus == BookingStatus.completed) {
        updateData['completionDate'] = FieldValue.serverTimestamp();
      }
      
      await _firestore.collection('bookings').doc(bookingId).update(updateData);
      
      // Get booking details for notification
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (bookingDoc.exists) {
        Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
        
        // Send notification to customer
        await NotificationService.sendNotificationToUser(
          userId: bookingData['customerId'],
          title: 'Booking Status Updated',
          body: 'Your booking status has been updated to ${newStatus.name}',
          data: {
            'type': 'booking_status_update',
            'bookingId': bookingId,
            'status': newStatus.name,
          },
        );
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Cancel booking
  static Future<bool> cancelBooking({
    required String bookingId,
    required String userId,
    required String reason,
  }) async {
    try {
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (!bookingDoc.exists) {
        return false;
      }
      
      Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
      
      // Check if user can cancel this booking
      if (bookingData['customerId'] != userId && 
          bookingData['providerId'] != userId) {
        return false;
      }
      
      // Check if booking can be cancelled
      BookingStatus currentStatus = BookingStatus.values.firstWhere(
        (e) => e.name == bookingData['status'],
      );
      
      if (!_canCancelBooking(currentStatus)) {
        return false;
      }
      
      // Update booking status
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.cancelled.name,
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to the other party
      String notificationUserId = bookingData['customerId'] == userId 
          ? bookingData['providerId'] 
          : bookingData['customerId'];
      
      await NotificationService.sendNotificationToUser(
        userId: notificationUserId,
        title: 'Booking Cancelled',
        body: 'A booking has been cancelled',
        data: {
          'type': 'booking_cancelled',
          'bookingId': bookingId,
          'reason': reason,
        },
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Reschedule booking
  static Future<bool> rescheduleBooking({
    required String bookingId,
    required DateTime newDate,
    required String userId,
    String? reason,
  }) async {
    try {
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (!bookingDoc.exists) {
        return false;
      }
      
      Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
      
      // Check if user can reschedule this booking
      if (bookingData['customerId'] != userId && 
          bookingData['providerId'] != userId) {
        return false;
      }
      
      // Check if new date is available
      bool isAvailable = await _checkProviderAvailability(
        bookingData['providerId'],
        newDate,
        excludeBookingId: bookingId,
      );
      
      if (!isAvailable) {
        throw Exception('Provider is not available at the new time');
      }
      
      // Update booking
      await _firestore.collection('bookings').doc(bookingId).update({
        'scheduledDate': Timestamp.fromDate(newDate),
        'updatedAt': FieldValue.serverTimestamp(),
        'rescheduleReason': reason,
      });
      
      // Send notification to the other party
      String notificationUserId = bookingData['customerId'] == userId 
          ? bookingData['providerId'] 
          : bookingData['customerId'];
      
      await NotificationService.sendNotificationToUser(
        userId: notificationUserId,
        title: 'Booking Rescheduled',
        body: 'A booking has been rescheduled',
        data: {
          'type': 'booking_rescheduled',
          'bookingId': bookingId,
          'newDate': newDate.toIso8601String(),
        },
      );
      
      return true;
    } catch (e) {
      rethrow;
    }
  }
  
  // Complete booking and request review
  static Future<bool> completeBooking({
    required String bookingId,
    required String providerId,
    String? notes,
  }) async {
    try {
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (!bookingDoc.exists) {
        return false;
      }
      
      Map<String, dynamic> bookingData = bookingDoc.data() as Map<String, dynamic>;
      
      // Verify provider owns this booking
      if (bookingData['providerId'] != providerId) {
        return false;
      }
      
      // Update booking status
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.completed.name,
        'completionDate': FieldValue.serverTimestamp(),
        'providerNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send review request notification to customer
      await NotificationService.sendNotificationToUser(
        userId: bookingData['customerId'],
        title: 'Service Completed',
        body: 'Your service has been completed. Please leave a review!',
        data: {
          'type': 'review_request',
          'bookingId': bookingId,
          'providerId': providerId,
        },
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Get booking details
  static Future<Booking?> getBookingDetails(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      
      // Get additional data
      data['provider'] = await _getProviderData(data['providerId']);
      data['customer'] = await _getCustomerData(data['customerId']);
      data['service'] = await _getServiceData(data['serviceId']);
      
              return Booking.fromMap(data, id: doc.id);
    } catch (e) {
      return null;
    }
  }
  
  // Check provider availability
  static Future<bool> _checkProviderAvailability(
    String providerId,
    DateTime date, {
    String? excludeBookingId,
  }) async {
    try {
      // Get all bookings for the provider on the given date
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
      Query query = _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('requestedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestedDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: [
            BookingStatus.pending.name,
            BookingStatus.accepted.name,
            BookingStatus.inProgress.name,
          ]);
      
      if (excludeBookingId != null) {
        query = query.where(FieldPath.documentId, isNotEqualTo: excludeBookingId);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      // Check if provider has too many bookings (max 8 per day)
      return snapshot.docs.length < 8;
    } catch (e) {
      return false;
    }
  }
  
  // Check if booking can be cancelled
  static bool _canCancelBooking(BookingStatus status) {
    return [
      BookingStatus.pending,
      BookingStatus.accepted,
    ].contains(status);
  }
  
  // Get provider data
  static Future<Map<String, dynamic>?> _getProviderData(String providerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Get customer data
  static Future<Map<String, dynamic>?> _getCustomerData(String customerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(customerId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Get service data
  static Future<Map<String, dynamic>?> _getServiceData(String serviceId) async {
    try {
      // This would typically come from the provider's services
      // For now, return a placeholder
      return {
        'id': serviceId,
        'name': 'Service',
        'description': 'Service description',
        'price': 0.0,
      };
    } catch (e) {
      return null;
    }
  }
  
  // Get booking statistics
  static Future<Map<String, dynamic>> getBookingStats(String userId, UserType userType) async {
    try {
      Query query = _firestore.collection('bookings');
      
      if (userType == UserType.customer) {
        query = query.where('customerId', isEqualTo: userId);
      } else {
        query = query.where('providerId', isEqualTo: userId);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      int total = snapshot.docs.length;
      int pending = 0;
      int confirmed = 0;
      int completed = 0;
      int cancelled = 0;
      double totalEarnings = 0.0;
      
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        
        switch (status) {
          case 'pending':
            pending++;
            break;
                  case 'accepted':
          confirmed++;
            break;
          case 'completed':
            completed++;
            if (userType == UserType.provider) {
              totalEarnings += (data['estimatedPrice'] ?? 0).toDouble();
            }
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }
      
      return {
        'total': total,
        'pending': pending,
        'confirmed': confirmed,
        'completed': completed,
        'cancelled': cancelled,
        'totalEarnings': totalEarnings,
      };
    } catch (e) {
      return {
        'total': 0,
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
        'totalEarnings': 0.0,
      };
    }
  }
}

enum UserType {
  customer,
  provider,
}
