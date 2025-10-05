import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('Shared Package Basic Tests', () {
    test('Package can be imported', () {
      // Test that the shared package can be imported without errors
      expect(true, isTrue);
    });

    test('User model can be created', () {
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
    });

    test('Provider model can be created', () {
      final provider = Provider(
        providerId: 'provider-123',
        businessName: 'Test Business',
        description: 'Test Description',
        categoryId: 'category-1',
        ownerUid: 'owner-123',
        createdAt: DateTime.now(),
      );
      expect(provider.providerId, 'provider-123');
      expect(provider.businessName, 'Test Business');
    });

    test('Booking model can be created', () {
      final booking = Booking(
        bookingId: 'booking-123',
        customerId: 'customer-123',
        providerId: 'provider-123',
        serviceId: 'service-123',
        status: 'pending',
        address: '123 Test Street',
        scheduledAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      expect(booking.bookingId, 'booking-123');
      expect(booking.status, 'pending');
    });

    test('Review model can be created', () {
      final review = Review(
        reviewId: 'review-123',
        bookingId: 'booking-123',
        customerId: 'customer-123',
        providerId: 'provider-123',
        rating: 5,
        comment: 'Great service!',
        createdAt: DateTime.now(),
      );
      expect(review.reviewId, 'review-123');
      expect(review.rating, 5);
    });

    test('Announcement model can be created', () {
      final announcement = Announcement(
        announcementId: 'announcement-123',
        title: 'Test Announcement',
        message: 'Test message',
        createdBy: 'admin-123',
        createdAt: DateTime.now(),
        audience: 'all',
      );
      expect(announcement.announcementId, 'announcement-123');
      expect(announcement.title, 'Test Announcement');
    });
  });
}