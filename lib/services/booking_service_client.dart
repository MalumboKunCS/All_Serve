import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';
import '../utils/app_logger.dart';

class BookingServiceClient {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Client-side booking creation with validation
  Future<String> createBooking({
    required String customerId,
    required String providerId,
    required String serviceId,
    required DateTime scheduledAt,
    required Map<String, dynamic> address,
    String? notes,
  }) async {
    try {
      AppLogger.info('BookingServiceClient: Creating booking for provider: $providerId');
      
      // 1. Validate provider exists and is active
      final providerDoc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (!providerDoc.exists) {
        throw Exception('Provider not found');
      }

      final providerData = providerDoc.data()!;
      if (providerData['status'] != 'active' || providerData['verified'] != true) {
        throw Exception('Provider is not available');
      }

      AppLogger.info('BookingServiceClient: Provider validation passed');

      // 2. Validate service exists
      final services = List<Map<String, dynamic>>.from(providerData['services'] ?? []);
      final serviceExists = services.any((service) => service['serviceId'] == serviceId);
      if (!serviceExists) {
        throw Exception('Service not found');
      }

      AppLogger.info('BookingServiceClient: Service validation passed');

      // 3. Check for conflicting bookings
      final conflictingBookings = await _checkBookingConflicts(
        providerId: providerId,
        scheduledAt: scheduledAt,
      );

      if (conflictingBookings.isNotEmpty) {
        throw Exception('Time slot is not available');
      }

      AppLogger.info('BookingServiceClient: No conflicts found');

      // 4. Create booking document
      final bookingId = DateTime.now().millisecondsSinceEpoch.toString();
      final booking = {
        'bookingId': bookingId,
        'customerId': customerId,
        'providerId': providerId,
        'serviceId': serviceId,
        'address': address,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'requestedAt': Timestamp.now(),
        'status': 'requested',
        'notes': notes,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await _firestore.collection('bookings').doc(bookingId).set(booking);
      
      AppLogger.info('BookingServiceClient: Booking created successfully with ID: $bookingId');
      return bookingId;
    } catch (e) {
      AppLogger.info('BookingServiceClient: Error creating booking: $e');
      rethrow;
    }
  }

  // Check for booking conflicts
  Future<List<QueryDocumentSnapshot>> _checkBookingConflicts({
    required String providerId,
    required DateTime scheduledAt,
  }) async {
    try {
      // Check for bookings within 2 hours of the scheduled time
      final startTime = scheduledAt.subtract(const Duration(hours: 1));
      final endTime = scheduledAt.add(const Duration(hours: 1));

      final query = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', whereIn: ['requested', 'accepted'])
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
          .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .get();

      AppLogger.info('BookingServiceClient: Found ${query.docs.length} conflicting bookings');
      return query.docs;
    } catch (e) {
      AppLogger.info('BookingServiceClient: Error checking conflicts: $e');
      return [];
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus({
    required String bookingId,
    required String status,
    String? notes,
  }) async {
    try {
      AppLogger.info('BookingServiceClient: Updating booking $bookingId to status: $status');
      
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': Timestamp.now(),
      };

      if (notes != null) {
        updateData['providerNotes'] = notes;
      }

      if (status == 'completed') {
        updateData['completedAt'] = Timestamp.now();
      }

      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updateData);

      AppLogger.info('BookingServiceClient: Booking status updated successfully');
      return true;
    } catch (e) {
      AppLogger.info('BookingServiceClient: Error updating booking status: $e');
      return false;
    }
  }

  // Get user bookings
  Future<List<Booking>> getUserBookings({
    required String userId,
    String? status,
    int limit = 20,
  }) async {
    try {
      AppLogger.info('BookingServiceClient: Fetching bookings for user: $userId');
      
      var query = _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      
      final bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        return Booking.fromMap(data, id: doc.id);
      }).toList();

      AppLogger.info('BookingServiceClient: Found ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      AppLogger.info('BookingServiceClient: Error fetching user bookings: $e');
      return [];
    }
  }

  // Get provider bookings
  Future<List<Booking>> getProviderBookings({
    required String providerId,
    String? status,
    int limit = 20,
  }) async {
    try {
      AppLogger.info('BookingServiceClient: Fetching bookings for provider: $providerId');
      
      var query = _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      
      final bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        return Booking.fromMap(data, id: doc.id);
      }).toList();

      AppLogger.info('BookingServiceClient: Found ${bookings.length} provider bookings');
      return bookings;
    } catch (e) {
      AppLogger.info('BookingServiceClient: Error fetching provider bookings: $e');
      return [];
    }
  }

  // Cancel booking
  Future<bool> cancelBooking({
    required String bookingId,
    required String userId,
    String? reason,
  }) async {
    try {
      AppLogger.info('BookingServiceClient: Cancelling booking: $bookingId');
      
      // Verify user owns the booking
      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data()!;
      if (bookingData['customerId'] != userId) {
        throw Exception('Unauthorized to cancel this booking');
      }

      if (bookingData['status'] == 'completed') {
        throw Exception('Cannot cancel completed booking');
      }

      final updateData = <String, dynamic>{
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
        'cancelledBy': userId,
        'updatedAt': Timestamp.now(),
      };

      if (reason != null) {
        updateData['cancellationReason'] = reason;
      }

      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updateData);

      AppLogger.info('BookingServiceClient: Booking cancelled successfully');
      return true;
    } catch (e) {
      AppLogger.info('BookingServiceClient: Error cancelling booking: $e');
      return false;
    }
  }
}
