import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/time_slot.dart';
import '../models/provider.dart' as app_provider;
import 'notification_service.dart';

class EnhancedBookingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new booking with real-time availability checking
  static Future<String?> createBooking({
    required String customerId,
    required String providerId,
    required String serviceId,
    required String serviceTitle,
    required String serviceCategory,
    required double estimatedPrice,
    required int durationMinutes,
    required DateTime scheduledAt,
    required Map<String, dynamic> address,
    String? customerNotes,
    String? timeSlot,
    bool isUrgent = false,
    List<String> specialRequirements = const [],
    String? customerFullName,
    String? customerPhoneNumber,
    String? customerEmailAddress,
    String? additionalNotes,
  }) async {
    try {
      // 1. Check provider availability in real-time
      final isAvailable = await checkProviderAvailability(
        providerId: providerId,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
      );

      if (!isAvailable) {
        throw Exception('Provider is not available at the selected time');
      }

      // 2. Get provider and customer data for the booking
      final providerData = await _getProviderData(providerId);
      final customerData = await _getCustomerData(customerId);
      final serviceData = await _getServiceData(providerId, serviceId);

      if (providerData == null) {
        throw Exception('Provider not found');
      }

      if (customerData == null) {
        throw Exception('Customer not found');
      }

      // 3. Create booking document
      final now = DateTime.now();
      final bookingRef = await _firestore.collection('bookings').add({
        'customerId': customerId,
        'providerId': providerId,
        'serviceId': serviceId,
        'serviceTitle': serviceTitle,
        'serviceCategory': serviceCategory,
        'estimatedPrice': estimatedPrice,
        'finalPrice': 0.0,
        'durationMinutes': durationMinutes,
        'address': address,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'requestedAt': Timestamp.fromDate(now),
        'status': BookingStatus.pending.name,
        'customerNotes': customerNotes,
        'providerNotes': null,
        'cancellationReason': null,
        'rescheduleReason': null,
        'completedAt': null,
        'cancelledAt': null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
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
      });

      final bookingId = bookingRef.id;

      // 4. Update time slot availability if timeSlot is provided
      if (timeSlot != null) {
        await _updateTimeSlotAvailability(providerId, scheduledAt, timeSlot, bookingId);
      }

      // 5. Send notifications
      await _sendBookingNotifications(bookingId, customerId, providerId, serviceTitle);

      // 6. Update provider's booking count
      await _updateProviderBookingStats(providerId);

      return bookingId;
    } catch (e) {
      debugPrint('Error creating booking: $e');
      rethrow;
    }
  }

  // Check provider availability in real-time
  static Future<bool> checkProviderAvailability({
    required String providerId,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? excludeBookingId,
  }) async {
    try {
      // Get provider's working hours and availability
      final provider = await _getProviderById(providerId);
      if (provider == null) return false;

      // Check if provider is active
      if (provider.status != 'active') return false;

      // Check if the requested time is within working hours
      if (!_isWithinWorkingHours(provider, scheduledAt)) return false;

      // Check for existing bookings that overlap
      final endTime = scheduledAt.add(Duration(minutes: durationMinutes));
      final overlappingBookings = await _getOverlappingBookings(
        providerId: providerId,
        startTime: scheduledAt,
        endTime: endTime,
        excludeBookingId: excludeBookingId,
      );

      // Check if provider has reached daily booking limit
      final dailyBookings = await _getDailyBookingCount(providerId, scheduledAt);
      const maxDailyBookings = 8; // Maximum bookings per day

      return overlappingBookings.isEmpty && dailyBookings < maxDailyBookings;
    } catch (e) {
      debugPrint('Error checking provider availability: $e');
      return false;
    }
  }

  // Get available time slots for a provider on a specific date
  static Future<List<TimeSlot>> getAvailableTimeSlots({
    required String providerId,
    required DateTime date,
    required int durationMinutes,
  }) async {
    try {
      final provider = await _getProviderById(providerId);
      if (provider == null) return [];

      // Generate time slots based on provider's working hours
      final timeSlots = _generateTimeSlots(provider, date, durationMinutes);

      // Check which slots are available
      final availableSlots = <TimeSlot>[];
      for (final slot in timeSlots) {
        final isAvailable = await checkProviderAvailability(
          providerId: providerId,
          scheduledAt: slot.startDateTime,
          durationMinutes: durationMinutes,
        );

        if (isAvailable) {
          availableSlots.add(slot);
        }
      }

      return availableSlots;
    } catch (e) {
      debugPrint('Error getting available time slots: $e');
      return [];
    }
  }

  // Update booking status
  static Future<bool> updateBookingStatus({
    required String bookingId,
    required BookingStatus newStatus,
    String? providerNotes,
    String? cancellationReason,
    String? rescheduleReason,
    double? finalPrice,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (providerNotes != null) {
        updateData['providerNotes'] = providerNotes;
      }

      if (cancellationReason != null) {
        updateData['cancellationReason'] = cancellationReason;
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
      }

      if (rescheduleReason != null) {
        updateData['rescheduleReason'] = rescheduleReason;
      }

      if (finalPrice != null) {
        updateData['finalPrice'] = finalPrice;
      }

      if (newStatus == BookingStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('bookings').doc(bookingId).update(updateData);

      // Send notification to customer
      await _sendStatusUpdateNotification(bookingId, newStatus);

      return true;
    } catch (e) {
      debugPrint('Error updating booking status: $e');
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
      final booking = await getBookingById(bookingId);
      if (booking == null) return false;

      // Check if user can cancel this booking
      if (booking.customerId != userId && booking.providerId != userId) {
        return false;
      }

      // Check if booking can be cancelled
      if (!booking.canBeCancelled) {
        return false;
      }

      // Update booking status
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Free up the time slot if it was booked
      if (booking.timeSlot != null) {
        await _freeTimeSlot(booking.providerId, booking.scheduledAt, booking.timeSlot!);
      }

      // Send notification to the other party
      final notificationUserId = booking.customerId == userId 
          ? booking.providerId 
          : booking.customerId;

      await NotificationService.sendNotificationToUser(
        userId: notificationUserId,
        title: 'Booking Cancelled',
        body: 'A booking has been cancelled: $reason',
        data: {
          'type': 'booking_cancelled',
          'bookingId': bookingId,
          'reason': reason,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      return false;
    }
  }

  // Reschedule booking
  static Future<bool> rescheduleBooking({
    required String bookingId,
    required DateTime newScheduledAt,
    required String userId,
    String? reason,
    String? newTimeSlot,
  }) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) return false;

      // Check if user can reschedule this booking
      if (booking.customerId != userId && booking.providerId != userId) {
        return false;
      }

      // Check if booking can be rescheduled
      if (!booking.canBeRescheduled) {
        return false;
      }

      // Check if new time is available
      final isAvailable = await checkProviderAvailability(
        providerId: booking.providerId,
        scheduledAt: newScheduledAt,
        durationMinutes: booking.durationMinutes,
        excludeBookingId: bookingId,
      );

      if (!isAvailable) {
        throw Exception('Provider is not available at the new time');
      }

      // Update booking
      await _firestore.collection('bookings').doc(bookingId).update({
        'scheduledAt': Timestamp.fromDate(newScheduledAt),
        'timeSlot': newTimeSlot,
        'rescheduleReason': reason,
        'status': BookingStatus.rescheduled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update time slots
      if (booking.timeSlot != null) {
        await _freeTimeSlot(booking.providerId, booking.scheduledAt, booking.timeSlot!);
      }
      if (newTimeSlot != null) {
        await _updateTimeSlotAvailability(booking.providerId, newScheduledAt, newTimeSlot, bookingId);
      }

      // Send notification to the other party
      final notificationUserId = booking.customerId == userId 
          ? booking.providerId 
          : booking.customerId;

      await NotificationService.sendNotificationToUser(
        userId: notificationUserId,
        title: 'Booking Rescheduled',
        body: 'A booking has been rescheduled to ${_formatDateTime(newScheduledAt)}',
        data: {
          'type': 'booking_rescheduled',
          'bookingId': bookingId,
          'newDate': newScheduledAt.toIso8601String(),
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error rescheduling booking: $e');
      rethrow;
    }
  }

  // Get booking by ID
  static Future<Booking?> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return null;
      return Booking.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting booking: $e');
      return null;
    }
  }

  // Get user bookings (customer or provider)
  static Future<List<Booking>> getUserBookings({
    required String userId,
    required UserType userType,
    BookingStatus? status,
    int limit = 20,
    DocumentSnapshot? startAfter,
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
      
      query = query.orderBy('scheduledAt', descending: true).limit(limit);
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting user bookings: $e');
      return [];
    }
  }

  // Get booking statistics
  static Future<Map<String, dynamic>> getBookingStats(String userId, UserType userType) async {
    try {
      final bookings = await getUserBookings(userId: userId, userType: userType, limit: 1000);
      
      int total = bookings.length;
      int pending = bookings.where((b) => b.isPending).length;
      int accepted = bookings.where((b) => b.isAccepted).length;
      int completed = bookings.where((b) => b.isCompleted).length;
      int cancelled = bookings.where((b) => b.isCancelled).length;
      int inProgress = bookings.where((b) => b.isInProgress).length;
      
      double totalEarnings = 0.0;
      if (userType == UserType.provider) {
        totalEarnings = bookings
            .where((b) => b.isCompleted)
            .fold(0.0, (sum, b) => sum + b.totalPrice);
      }
      
      double totalSpent = 0.0;
      if (userType == UserType.customer) {
        totalSpent = bookings
            .where((b) => b.isCompleted)
            .fold(0.0, (sum, b) => sum + b.totalPrice);
      }

      return {
        'total': total,
        'pending': pending,
        'accepted': accepted,
        'completed': completed,
        'cancelled': cancelled,
        'inProgress': inProgress,
        'totalEarnings': totalEarnings,
        'totalSpent': totalSpent,
        'completionRate': total > 0 ? (completed / total) * 100 : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting booking stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'completed': 0,
        'cancelled': 0,
        'inProgress': 0,
        'totalEarnings': 0.0,
        'totalSpent': 0.0,
        'completionRate': 0.0,
      };
    }
  }

  // Stream of real-time booking updates
  static Stream<List<Booking>> getBookingsStream({
    required String userId,
    required UserType userType,
    BookingStatus? status,
  }) {
    Query query = _firestore.collection('bookings');
    
    if (userType == UserType.customer) {
      query = query.where('customerId', isEqualTo: userId);
    } else {
      query = query.where('providerId', isEqualTo: userId);
    }
    
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    
    // Remove orderBy to avoid index requirement - we'll sort client-side
    // query = query.orderBy('scheduledAt', descending: true);
    
    return query.snapshots().map((snapshot) {
      final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
      
      // Sort client-side by scheduledAt in descending order (most recent first)
      bookings.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      
      return bookings;
    });
  }

  // Private helper methods
  static Future<Map<String, dynamic>?> _getProviderData(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting provider data: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getCustomerData(String customerId) async {
    try {
      final doc = await _firestore.collection('users').doc(customerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting customer data: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getServiceData(String providerId, String serviceId) async {
    try {
      final provider = await _getProviderById(providerId);
      if (provider == null) return null;

      final service = provider.services.firstWhere(
        (s) => s.serviceId == serviceId,
        orElse: () => throw Exception('Service not found'),
      );

      return {
        'serviceId': service.serviceId,
        'title': service.title,
        'category': service.category,
        'description': service.description,
        'priceFrom': service.priceFrom,
        'priceTo': service.priceTo,
        'duration': service.duration,
        'type': service.type,
        'imageUrl': service.imageUrl,
        'availability': service.availability,
      };
    } catch (e) {
      debugPrint('Error getting service data: $e');
      return null;
    }
  }

  static Future<app_provider.Provider?> _getProviderById(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      if (doc.exists) {
        return app_provider.Provider.fromMap(doc.data()!, id: doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting provider: $e');
      return null;
    }
  }

  static bool _isWithinWorkingHours(app_provider.Provider provider, DateTime scheduledAt) {
    // This is a simplified check - in production, you'd check against actual working hours
    final hour = scheduledAt.hour;
    return hour >= 8 && hour <= 18; // 8 AM to 6 PM
  }

  static Future<List<Booking>> _getOverlappingBookings({
    required String providerId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeBookingId,
  }) async {
    try {
      Query query = _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', whereIn: [
            BookingStatus.pending.name,
            BookingStatus.accepted.name,
            BookingStatus.inProgress.name,
          ]);

      if (excludeBookingId != null) {
        query = query.where(FieldPath.documentId, isNotEqualTo: excludeBookingId);
      }

      final snapshot = await query.get();
      final bookings = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();

      return bookings.where((booking) {
        final bookingStart = booking.scheduledAt;
        final bookingEnd = bookingStart.add(Duration(minutes: booking.durationMinutes));
        
        return startTime.isBefore(bookingEnd) && endTime.isAfter(bookingStart);
      }).toList();
    } catch (e) {
      debugPrint('Error getting overlapping bookings: $e');
      return [];
    }
  }

  static Future<int> _getDailyBookingCount(String providerId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledAt', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: [
            BookingStatus.pending.name,
            BookingStatus.accepted.name,
            BookingStatus.inProgress.name,
          ])
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting daily booking count: $e');
      return 0;
    }
  }

  static List<TimeSlot> _generateTimeSlots(app_provider.Provider provider, DateTime date, int durationMinutes) {
    final slots = <TimeSlot>[];
    final now = DateTime.now();
    
    // Generate slots from 8 AM to 6 PM, every 30 minutes
    for (int hour = 8; hour < 18; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final startTime = DateTime(date.year, date.month, date.day, hour, minute);
        final endTime = startTime.add(Duration(minutes: durationMinutes));
        
        // Skip past times
        if (startTime.isBefore(now)) continue;
        
        // Skip if end time goes beyond working hours
        if (endTime.hour > 18) continue;
        
        final timeSlot = TimeSlot(
          slotId: '${provider.providerId}_${startTime.millisecondsSinceEpoch}',
          providerId: provider.providerId,
          date: date,
          startTime: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          endTime: '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
          isAvailable: true,
          createdAt: now,
          updatedAt: now,
        );
        
        slots.add(timeSlot);
      }
    }
    
    return slots;
  }

  static Future<void> _updateTimeSlotAvailability(
    String providerId,
    DateTime date,
    String timeSlot,
    String bookingId,
  ) async {
    try {
      await _firestore.collection('time_slots').add({
        'providerId': providerId,
        'date': Timestamp.fromDate(date),
        'timeSlot': timeSlot,
        'isAvailable': false,
        'bookingId': bookingId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating time slot availability: $e');
    }
  }

  static Future<void> _freeTimeSlot(
    String providerId,
    DateTime date,
    String timeSlot,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('time_slots')
          .where('providerId', isEqualTo: providerId)
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('timeSlot', isEqualTo: timeSlot)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'isAvailable': true,
          'bookingId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error freeing time slot: $e');
    }
  }

  static Future<void> _sendBookingNotifications(
    String bookingId,
    String customerId,
    String providerId,
    String serviceTitle,
  ) async {
    try {
      // Notify provider
      await NotificationService.sendNotificationToUser(
        userId: providerId,
        title: 'New Booking Request',
        body: 'You have a new booking request for $serviceTitle',
        data: {
          'type': 'new_booking',
          'bookingId': bookingId,
        },
      );

      // Notify customer
      await NotificationService.sendNotificationToUser(
        userId: customerId,
        title: 'Booking Confirmed',
        body: 'Your booking request has been submitted successfully',
        data: {
          'type': 'booking_confirmed',
          'bookingId': bookingId,
        },
      );
    } catch (e) {
      debugPrint('Error sending booking notifications: $e');
    }
  }

  static Future<void> _sendStatusUpdateNotification(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) return;

      String title = 'Booking Status Updated';
      String body = 'Your booking status has been updated to ${newStatus.name}';

      await NotificationService.sendNotificationToUser(
        userId: booking.customerId,
        title: title,
        body: body,
        data: {
          'type': 'booking_status_update',
          'bookingId': bookingId,
          'status': newStatus.name,
        },
      );
    } catch (e) {
      debugPrint('Error sending status update notification: $e');
    }
  }

  static Future<void> _updateProviderBookingStats(String providerId) async {
    try {
      final stats = await getBookingStats(providerId, UserType.provider);
      await _firestore.collection('providers').doc(providerId).update({
        'totalBookings': stats['total'],
        'completedBookings': stats['completed'],
        'completionRate': stats['completionRate'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating provider booking stats: $e');
    }
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

enum UserType {
  customer,
  provider,
}
          