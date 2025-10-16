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

    test('AppTheme text styles are defined', () {
      // Test that text styles exist
      expect(AppTheme.heading1, isA<TextStyle>());
      expect(AppTheme.heading2, isA<TextStyle>());
      expect(AppTheme.heading3, isA<TextStyle>());
      expect(AppTheme.bodyLarge, isA<TextStyle>());
      expect(AppTheme.bodyMedium, isA<TextStyle>());
      expect(AppTheme.caption, isA<TextStyle>());
    });

    test('Models can be instantiated', () {
      // Test User model
      final user = User(
        uid: 'test-uid',
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        role: 'customer',
        deviceTokens: [],
        createdAt: DateTime.now(),
      );
      expect(user.uid, 'test-uid');
      expect(user.name, 'Test User');
      expect(user.role, 'customer');
      
      // Test Provider model
      final provider = Provider(
        providerId: 'test-provider-id',
        ownerUid: 'test-uid',
        businessName: 'Test Business',
        description: 'Test Description',
        categoryId: 'test-category',
        services: [],
        images: [],
        lat: 0.0,
        lng: 0.0,
        geohash: 'test-geohash',
        serviceAreaKm: 10.0,
        documents: {},
        createdAt: DateTime.now(),
        keywords: [],
      );
      expect(provider.providerId, 'test-provider-id');
      expect(provider.businessName, 'Test Business');
      expect(provider.ownerUid, 'test-uid');
      
      // Test Booking model
      final booking = Booking(
        bookingId: 'test-booking-id',
        customerId: 'test-customer-id',
        providerId: 'test-provider-id',
        serviceId: 'test-service-id',
        address: {'address': 'Test Address', 'lat': 0.0, 'lng': 0.0},
        scheduledAt: DateTime.now(),
        requestedAt: DateTime.now(),
        status: 'requested',
        createdAt: DateTime.now(),
      );
      expect(booking.bookingId, 'test-booking-id');
      expect(booking.status, 'requested');
    });
  });
}