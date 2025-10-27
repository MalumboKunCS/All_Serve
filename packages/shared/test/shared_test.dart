import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('Shared Package Basic Tests', () {
    test('Package can be imported', () {
      // Test that the shared package can be imported without errors
      expect(true, isTrue);
    });

    test('AppTheme constants are defined', () {
      // Test that theme constants exist and have expected values
      expect(AppTheme.primaryPurple, isA<Color>());
      expect(AppTheme.primaryBlue, isA<Color>());
      expect(AppTheme.success, isA<Color>());
      expect(AppTheme.error, isA<Color>());
      expect(AppTheme.warning, isA<Color>());
      expect(AppTheme.info, isA<Color>());
    });

    // Skipping text style tests as they require GoogleFonts which needs font loading
    // This doesn't work in unit tests without proper mocking
    // In integration tests or widget tests, these would be tested properly

    test('Booking model can be instantiated with new fields', () {
      // Test that the enhanced Booking model works correctly
      final now = DateTime.now();
      final booking = Booking(
        bookingId: 'test-booking-id',
        customerId: 'test-customer-id',
        providerId: 'test-provider-id',
        serviceId: 'test-service-id',
        serviceTitle: 'Test Service',
        serviceCategory: 'Test Category',
        estimatedPrice: 100.0,
        durationMinutes: 60,
        address: {'address': 'Test Address', 'lat': 0.0, 'lng': 0.0},
        scheduledAt: now,
        requestedAt: now,
        status: BookingStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      
      // Test required fields
      expect(booking.bookingId, 'test-booking-id');
      expect(booking.customerId, 'test-customer-id');
      expect(booking.providerId, 'test-provider-id');
      expect(booking.serviceId, 'test-service-id');
      expect(booking.serviceTitle, 'Test Service');
      expect(booking.serviceCategory, 'Test Category');
      expect(booking.estimatedPrice, 100.0);
      expect(booking.durationMinutes, 60);
      expect(booking.status, BookingStatus.pending);
      
      // Test optional fields with defaults
      expect(booking.finalPrice, 0.0);
      expect(booking.isUrgent, false);
      expect(booking.hasReview, false);
      expect(booking.specialRequirements, isEmpty);
      
      // Test helper getters
      expect(booking.isPending, true);
      expect(booking.isCompleted, false);
      expect(booking.canBeCancelled, true);
    });

    test('BookingStatus enum values are correct', () {
      expect(BookingStatus.values.length, 7);
      expect(BookingStatus.pending.name, 'pending');
      expect(BookingStatus.accepted.name, 'accepted');
      expect(BookingStatus.inProgress.name, 'inProgress');
      expect(BookingStatus.completed.name, 'completed');
      expect(BookingStatus.cancelled.name, 'cancelled');
      expect(BookingStatus.rejected.name, 'rejected');
      expect(BookingStatus.rescheduled.name, 'rescheduled');
    });

    test('PaymentStatus enum values are correct', () {
      expect(PaymentStatus.values.length, 5);
      expect(PaymentStatus.unpaid.name, 'unpaid');
      expect(PaymentStatus.paid.name, 'paid');
      expect(PaymentStatus.refunded.name, 'refunded');
      expect(PaymentStatus.failed.name, 'failed');
      expect(PaymentStatus.pending.name, 'pending');
    });
  });
}