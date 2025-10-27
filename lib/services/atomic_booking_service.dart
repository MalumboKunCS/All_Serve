import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/provider.dart' as app_provider;
import '../utils/app_logger.dart';
import 'booking_validation_service.dart';
import 'notification_service.dart';

/// Service for atomic booking operations using Firestore transactions
/// This prevents race conditions and double-booking scenarios
class AtomicBookingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a booking using Firestore transaction to prevent double-booking
  /// 
  /// This method ensures atomicity by:
  /// 1. Checking provider availability within a transaction
  /// 2. Creating the booking document only if no conflicts exist
  /// 3. Rolling back if any step fails
  /// 
  /// Returns booking ID on success, throws exception on failure
  static Future<String> createBookingAtomic({
    required String customerId,
    required String providerId,
    required String serviceId,
    required String serviceTitle,
    required String serviceCategory,
    required DateTime scheduledAt,
    required int durationMinutes,
    required double estimatedPrice,
    required Map<String, dynamic> address,
    String? customerNotes,
    String? timeSlot,
    bool isUrgent = false,
    List<String> specialRequirements = const [],
    String? customerFullName,
    required String customerPhoneNumber,
    String? customerEmailAddress,
    String? additionalNotes,
    String? timezone,
  }) async {
    try {
      // Step 1: Pre-transaction validation
      final validationResult = BookingValidationService.validateBookingCreation(
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        estimatedPrice: estimatedPrice,
        timezone: timezone,
      );

      if (!validationResult.isValid) {
        throw BookingValidationException(validationResult.errorMessage);
      }

      AppLogger.info(
        'Starting atomic booking creation: '
        'provider=$providerId, scheduled=${scheduledAt.toIso8601String()}'
      );

      // Step 2: Execute transaction
      final bookingId = await _firestore.runTransaction<String>(
        (transaction) async {
          // 2a. Check for overlapping bookings atomically
          final endTime = scheduledAt.add(Duration(minutes: durationMinutes));
          final overlappingBookings = await _checkOverlappingBookingsInTransaction(
            transaction: transaction,
            providerId: providerId,
            startTime: scheduledAt,
            endTime: endTime,
          );

          if (overlappingBookings.isNotEmpty) {
            throw BookingConflictException(
              'Time slot is no longer available. '
              'Found ${overlappingBookings.length} overlapping booking(s).'
            );
          }

          // 2b. Check daily booking limit
          final dailyCount = await _getDailyBookingCountInTransaction(
            transaction: transaction,
            providerId: providerId,
            date: scheduledAt,
          );

          const maxDailyBookings = 8;
          if (dailyCount >= maxDailyBookings) {
            throw BookingLimitException(
              'Provider has reached daily booking limit ($maxDailyBookings)'
            );
          }

          // 2c. Get provider and customer data
          final providerData = await _getProviderDataInTransaction(
            transaction: transaction,
            providerId: providerId,
          );

          final customerData = await _getCustomerDataInTransaction(
            transaction: transaction,
            customerId: customerId,
          );

          final serviceData = await _getServiceDataInTransaction(
            transaction: transaction,
            providerId: providerId,
            serviceId: serviceId,
          );

          // 2d. Create booking document atomically
          final bookingRef = _firestore.collection('bookings').doc();
          final now = DateTime.now();

          final booking = {
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
            'paymentStatus': PaymentStatus.unpaid.name,
            'paymentId': null,
            'paymentMethod': null,
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
            'hasReview': false,
            'reviewId': null,
            'timezone': timezone ?? 'UTC',
          };

          transaction.set(bookingRef, booking);

          AppLogger.info('Booking created atomically: ${bookingRef.id}');
          return bookingRef.id;
        },
        timeout: const Duration(seconds: 10),
      );

      // Step 3: Post-transaction operations (notifications, etc.)
      await _postBookingCreation(
        bookingId: bookingId,
        customerId: customerId,
        providerId: providerId,
        serviceTitle: serviceTitle,
      );

      return bookingId;
    } on BookingException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to create atomic booking: $e', stackTrace);
      throw BookingCreationException(
        'Failed to create booking. Please try again. Error: ${e.toString()}'
      );
    }
  }

  /// Updates booking status atomically with validation
  static Future<void> updateBookingStatusAtomic({
    required String bookingId,
    required BookingStatus newStatus,
    required String userId,
    String? providerNotes,
    String? cancellationReason,
    double? finalPrice,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get current booking
        final bookingRef = _firestore.collection('bookings').doc(bookingId);
        final bookingDoc = await transaction.get(bookingRef);

        if (!bookingDoc.exists) {
          throw BookingNotFoundException('Booking not found: $bookingId');
        }

        final currentBooking = Booking.fromFirestore(bookingDoc);

        // Validate state transition
        if (!BookingValidationService.canTransitionTo(
          currentStatus: currentBooking.status,
          newStatus: newStatus,
        )) {
          throw InvalidStateTransitionException(
            'Cannot transition from ${currentBooking.status.name} to ${newStatus.name}'
          );
        }

        // Validate user permission
        if (currentBooking.customerId != userId &&
            currentBooking.providerId != userId) {
          throw UnauthorizedException(
            'User does not have permission to update this booking'
          );
        }

        // Track provider metrics if provider is accepting or cancelling an accepted booking
        // NOTE: This must be done BEFORE any writes to comply with Firestore transaction rules
        if (userId == currentBooking.providerId) {
          if (newStatus == BookingStatus.accepted && currentBooking.status == BookingStatus.pending) {
            // Provider accepted a booking - increment acceptedCount
            await _incrementProviderMetric(
              transaction: transaction,
              providerId: currentBooking.providerId,
              metric: 'acceptedCount',
            );
          } else if (newStatus == BookingStatus.cancelled && 
                     (currentBooking.status == BookingStatus.accepted || 
                      currentBooking.status == BookingStatus.inProgress)) {
            // Provider cancelled an accepted booking - increment cancellationCount
            await _incrementProviderMetric(
              transaction: transaction,
              providerId: currentBooking.providerId,
              metric: 'cancellationCount',
            );
          }
        }

        // Prepare update data
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

        if (finalPrice != null && finalPrice > 0) {
          updateData['finalPrice'] = finalPrice;
        }

        if (newStatus == BookingStatus.completed) {
          updateData['completedAt'] = FieldValue.serverTimestamp();
        }

        // Update atomically
        transaction.update(bookingRef, updateData);

        AppLogger.info(
          'Booking status updated atomically: $bookingId -> ${newStatus.name}'
        );
      });

      // Send notification after transaction
      await _sendStatusUpdateNotification(bookingId, newStatus);
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to update booking status atomically: $e', stackTrace);
      rethrow;
    }
  }

  /// Cancels booking atomically with validation
  static Future<void> cancelBookingAtomic({
    required String bookingId,
    required String userId,
    required String reason,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final bookingRef = _firestore.collection('bookings').doc(bookingId);
        final bookingDoc = await transaction.get(bookingRef);

        if (!bookingDoc.exists) {
          throw BookingNotFoundException('Booking not found: $bookingId');
        }

        final booking = Booking.fromFirestore(bookingDoc);

        // Validate cancellation
        final validation = BookingValidationService.validateCancellation(
          booking: booking,
          userId: userId,
        );

        if (!validation.isValid) {
          throw BookingValidationException(validation.errorMessage);
        }

        // Update booking
        transaction.update(bookingRef, {
          'status': BookingStatus.cancelled.name,
          'cancellationReason': reason,
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger.info('Booking cancelled atomically: $bookingId');
      });

      // Notify other party after transaction
      await _sendCancellationNotification(bookingId, userId, reason);
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to cancel booking atomically: $e', stackTrace);
      rethrow;
    }
  }

  /// Confirms booking completion by customer after provider marks it complete
  /// This implements the two-step completion flow:
  /// 1. Provider marks as pendingCustomerConfirmation
  /// 2. Customer confirms completion (this method)
  static Future<void> confirmBookingCompletion({
    required String bookingId,
    required String customerId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final bookingRef = _firestore.collection('bookings').doc(bookingId);
        final bookingDoc = await transaction.get(bookingRef);

        if (!bookingDoc.exists) {
          throw BookingNotFoundException('Booking not found: $bookingId');
        }

        final booking = Booking.fromFirestore(bookingDoc);

        // Validate that the customer owns this booking
        if (booking.customerId != customerId) {
          throw BookingValidationException(
            'Unauthorized: You can only confirm your own bookings'
          );
        }

        // Validate that booking is in pendingCustomerConfirmation status
        if (!booking.canBeConfirmedByCustomer) {
          throw BookingValidationException(
            'Booking cannot be confirmed in current status: ${booking.status.name}'
          );
        }

        // Update booking to completed
        transaction.update(bookingRef, {
          'status': BookingStatus.completed.name,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger.info('Booking completion confirmed by customer: $bookingId');
      });

      // Send notification to provider
      await _sendCompletionConfirmationNotification(bookingId, customerId);
    } catch (e, stackTrace) {
      AppLogger.errorWithStackTrace('Failed to confirm booking completion: $e', stackTrace);
      rethrow;
    }
  }

  // Private helper methods

  static Future<List<DocumentSnapshot>> _checkOverlappingBookingsInTransaction({
    required Transaction transaction,
    required String providerId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    // NOTE: Firestore transactions cannot execute queries, only read DocumentReferences
    // We need to query BEFORE the transaction and verify within the transaction
    // This approach uses optimistic locking - check before, verify during transaction
    
    // Get all active bookings for provider (outside transaction)
    final query = _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .where('status', whereIn: [
          BookingStatus.pending.name,
          BookingStatus.accepted.name,
          BookingStatus.inProgress.name,
        ]);

    final snapshot = await query.get();

    // Check for time overlaps
    final overlapping = <DocumentSnapshot>[];
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final bookingStart = (data['scheduledAt'] as Timestamp).toDate();
      final bookingDuration = data['durationMinutes'] as int? ?? 60;
      final bookingEnd = bookingStart.add(Duration(minutes: bookingDuration));

      // Check if there's any overlap
      if (startTime.isBefore(bookingEnd) && endTime.isAfter(bookingStart)) {
        // Re-verify within transaction to ensure consistency
        final transactionDoc = await transaction.get(doc.reference);
        if (transactionDoc.exists) {
          final transactionData = transactionDoc.data() as Map<String, dynamic>;
          final status = transactionData['status'] as String?;
          
          // Only consider if still in active status
          if (status == BookingStatus.pending.name ||
              status == BookingStatus.accepted.name ||
              status == BookingStatus.inProgress.name) {
            overlapping.add(transactionDoc);
          }
        }
      }
    }
    
    return overlapping;
  }

  static Future<int> _getDailyBookingCountInTransaction({
    required Transaction transaction,
    required String providerId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Query outside transaction, verify inside
    final query = _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(endOfDay))
        .where('status', whereIn: [
          BookingStatus.pending.name,
          BookingStatus.accepted.name,
          BookingStatus.inProgress.name,
        ]);

    final snapshot = await query.get();
    
    // Re-verify each booking in transaction to ensure accuracy
    int count = 0;
    for (final doc in snapshot.docs) {
      final transactionDoc = await transaction.get(doc.reference);
      if (transactionDoc.exists) {
        final data = transactionDoc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == BookingStatus.pending.name ||
            status == BookingStatus.accepted.name ||
            status == BookingStatus.inProgress.name) {
          count++;
        }
      }
    }
    
    return count;
  }

  static Future<Map<String, dynamic>?> _getProviderDataInTransaction({
    required Transaction transaction,
    required String providerId,
  }) async {
    final doc = await transaction.get(
      _firestore.collection('providers').doc(providerId)
    );

    if (!doc.exists) {
      throw ProviderNotFoundException('Provider not found: $providerId');
    }

    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  static Future<Map<String, dynamic>?> _getCustomerDataInTransaction({
    required Transaction transaction,
    required String customerId,
  }) async {
    final doc = await transaction.get(
      _firestore.collection('users').doc(customerId)
    );

    if (!doc.exists) {
      throw CustomerNotFoundException('Customer not found: $customerId');
    }

    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  static Future<Map<String, dynamic>?> _getServiceDataInTransaction({
    required Transaction transaction,
    required String providerId,
    required String serviceId,
  }) async {
    final providerDoc = await transaction.get(
      _firestore.collection('providers').doc(providerId)
    );

    if (!providerDoc.exists) {
      return null;
    }

    final provider = app_provider.Provider.fromMap(
      providerDoc.data()!,
      id: providerDoc.id,
    );

    try {
      final service = provider.services.firstWhere(
        (s) => s.serviceId == serviceId,
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
      };
    } catch (e) {
      throw ServiceNotFoundException('Service not found: $serviceId');
    }
  }

  /// Increments provider metrics (acceptedCount or cancellationCount) atomically
  static Future<void> _incrementProviderMetric({
    required Transaction transaction,
    required String providerId,
    required String metric,
  }) async {
    final providerRef = _firestore.collection('providers').doc(providerId);
    final providerDoc = await transaction.get(providerRef);

    if (!providerDoc.exists) {
      AppLogger.warning('Provider not found for metric update: $providerId');
      return;
    }

    // Increment the specified metric
    transaction.update(providerRef, {
      metric: FieldValue.increment(1),
    });

    AppLogger.info('Provider metric updated: $providerId.$metric += 1');
  }

  static Future<void> _postBookingCreation({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String serviceTitle,
  }) async {
    try {
      // Send notifications (fire-and-forget, don't block)
      unawaited(
        NotificationService.sendNotificationToUser(
          userId: providerId,
          title: 'New Booking Request',
          body: 'You have a new booking request for $serviceTitle',
          data: {
            'type': 'new_booking',
            'bookingId': bookingId,
          },
        )
      );

      unawaited(
        NotificationService.sendNotificationToUser(
          userId: customerId,
          title: 'Booking Confirmed',
          body: 'Your booking request has been submitted successfully',
          data: {
            'type': 'booking_confirmed',
            'bookingId': bookingId,
          },
        )
      );
    } catch (e) {
      AppLogger.warning('Failed to send post-booking notifications: $e');
      // Don't throw - notifications are not critical
    }
  }

  static Future<void> _sendStatusUpdateNotification(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    try {
      // Get booking details for notification
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return;

      final booking = Booking.fromFirestore(bookingDoc);

      // Notifications are sent from provider booking screen actions
      // This is a fallback for other status changes
      AppLogger.info('Booking status updated to ${newStatus.name}: $bookingId');
    } catch (e) {
      AppLogger.warning('Failed to send status update notification: $e');
      // Don't throw - notifications are not critical
    }
  }

  static Future<void> _sendCancellationNotification(
    String bookingId,
    String userId,
    String reason,
  ) async {
    try {
      // Get booking details
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return;

      final booking = Booking.fromFirestore(bookingDoc);

      // Determine who to notify (the other party)
      final targetUserId = booking.customerId == userId 
          ? booking.providerId 
          : booking.customerId;

      final isCustomer = booking.customerId == userId;

      await NotificationService.sendNotificationToUser(
        userId: targetUserId,
        title: isCustomer ? 'Customer Cancelled Booking' : 'Provider Cancelled Booking',
        body: 'Booking for ${booking.serviceTitle} was cancelled. Reason: $reason',
        data: {
          'type': NotificationType.bookingCancelled,
          'bookingId': bookingId,
        },
      );

      AppLogger.info('Cancellation notification sent for booking: $bookingId');
    } catch (e) {
      AppLogger.warning('Failed to send cancellation notification: $e');
      // Don't throw - notifications are not critical
    }
  }

  static Future<void> _sendCompletionConfirmationNotification(
    String bookingId,
    String customerId,
  ) async {
    try {
      // Get booking details
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return;

      final booking = Booking.fromFirestore(bookingDoc);

      // Notify provider that customer confirmed completion
      await NotificationService.sendNotificationToUser(
        userId: booking.providerId,
        title: 'Service Completion Confirmed',
        body: 'Customer has confirmed completion of ${booking.serviceTitle}. Final price: K${booking.finalPrice.toStringAsFixed(0)}',
        data: {
          'type': 'booking_completed',
          'bookingId': bookingId,
        },
      );

      AppLogger.info('Completion confirmation notification sent for booking: $bookingId');
    } catch (e) {
      AppLogger.warning('Failed to send completion confirmation notification: $e');
      // Don't throw - notifications are not critical
    }
  }
}

// Custom exceptions for better error handling

class BookingException implements Exception {
  final String message;
  BookingException(this.message);

  @override
  String toString() => 'BookingException: $message';
}

class BookingValidationException extends BookingException {
  BookingValidationException(super.message);
}

class BookingConflictException extends BookingException {
  BookingConflictException(super.message);
}

class BookingLimitException extends BookingException {
  BookingLimitException(super.message);
}

class BookingNotFoundException extends BookingException {
  BookingNotFoundException(super.message);
}

class BookingCreationException extends BookingException {
  BookingCreationException(super.message);
}

class InvalidStateTransitionException extends BookingException {
  InvalidStateTransitionException(super.message);
}

class UnauthorizedException extends BookingException {
  UnauthorizedException(super.message);
}

class ProviderNotFoundException extends BookingException {
  ProviderNotFoundException(super.message);
}

class CustomerNotFoundException extends BookingException {
  CustomerNotFoundException(super.message);
}

class ServiceNotFoundException extends BookingException {
  ServiceNotFoundException(super.message);
}
