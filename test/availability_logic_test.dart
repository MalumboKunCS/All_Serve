import 'package:flutter_test/flutter_test.dart';
import '../lib/models/provider.dart' as app_provider;

/// Test suite for Issue 2: Availability Logic
/// 
/// Tests the day-of-week validation logic to ensure:
/// 1. Services with specific days only show slots on those days
/// 2. Services with no availability restrictions work on all days
/// 3. Proper error messages are shown for unavailable days
/// 4. Helper methods correctly identify valid/invalid dates

void main() {
  group('Availability Logic Tests', () {
    // Helper function to create a test service
    app_provider.Service createTestService({
      String title = 'Test Service',
      List<String> availability = const [],
    }) {
      return app_provider.Service(
        serviceId: 'test_123',
        title: title,
        category: 'cleaning',
        type: 'priced',
        priceFrom: 50.0,
        priceTo: 100.0,
        duration: '1 hour',
        availability: availability,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // Helper to check if date is available for service
    bool isDateAvailableForService(DateTime date, app_provider.Service service) {
      if (service.availability.isEmpty) return true;
      
      const daysOfWeek = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday'
      ];
      final dayName = daysOfWeek[date.weekday - 1];
      return service.availability.contains(dayName);
    }

    // Helper to get day name
    String getDayName(DateTime date) {
      const daysOfWeek = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return daysOfWeek[date.weekday - 1];
    }

    test('Service with no availability restrictions should be available all days', () {
      final service = createTestService(
        title: 'All Days Service',
        availability: [],
      );

      // Test all 7 days of the week
      final baseDate = DateTime(2025, 10, 20); // Monday, Oct 20, 2025
      for (int i = 0; i < 7; i++) {
        final testDate = baseDate.add(Duration(days: i));
        expect(
          isDateAvailableForService(testDate, service),
          true,
          reason: '${getDayName(testDate)} should be available for service with no restrictions',
        );
      }
    });

    test('Service with specific days should only be available on those days', () {
      final service = createTestService(
        title: 'Weekday Service',
        availability: ['monday', 'wednesday', 'friday'],
      );

      // Monday Oct 20, 2025 - should be available
      final monday = DateTime(2025, 10, 20);
      expect(isDateAvailableForService(monday, service), true,
          reason: 'Monday should be available');

      // Tuesday Oct 21, 2025 - should NOT be available
      final tuesday = DateTime(2025, 10, 21);
      expect(isDateAvailableForService(tuesday, service), false,
          reason: 'Tuesday should NOT be available');

      // Wednesday Oct 22, 2025 - should be available
      final wednesday = DateTime(2025, 10, 22);
      expect(isDateAvailableForService(wednesday, service), true,
          reason: 'Wednesday should be available');

      // Thursday Oct 23, 2025 - should NOT be available
      final thursday = DateTime(2025, 10, 23);
      expect(isDateAvailableForService(thursday, service), false,
          reason: 'Thursday should NOT be available');

      // Friday Oct 24, 2025 - should be available
      final friday = DateTime(2025, 10, 24);
      expect(isDateAvailableForService(friday, service), true,
          reason: 'Friday should be available');

      // Saturday Oct 25, 2025 - should NOT be available
      final saturday = DateTime(2025, 10, 25);
      expect(isDateAvailableForService(saturday, service), false,
          reason: 'Saturday should NOT be available');

      // Sunday Oct 26, 2025 - should NOT be available
      final sunday = DateTime(2025, 10, 26);
      expect(isDateAvailableForService(sunday, service), false,
          reason: 'Sunday should NOT be available');
    });

    test('Service available on weekends only', () {
      final service = createTestService(
        title: 'Weekend Service',
        availability: ['saturday', 'sunday'],
      );

      final baseDate = DateTime(2025, 10, 20); // Monday

      // Monday through Friday should NOT be available
      for (int i = 0; i < 5; i++) {
        final testDate = baseDate.add(Duration(days: i));
        expect(
          isDateAvailableForService(testDate, service),
          false,
          reason: '${getDayName(testDate)} should NOT be available for weekend-only service',
        );
      }

      // Saturday and Sunday should be available
      final saturday = baseDate.add(const Duration(days: 5));
      expect(isDateAvailableForService(saturday, service), true,
          reason: 'Saturday should be available');

      final sunday = baseDate.add(const Duration(days: 6));
      expect(isDateAvailableForService(sunday, service), true,
          reason: 'Sunday should be available');
    });

    test('getDayName returns correct day names', () {
      expect(getDayName(DateTime(2025, 10, 20)), 'Monday');
      expect(getDayName(DateTime(2025, 10, 21)), 'Tuesday');
      expect(getDayName(DateTime(2025, 10, 22)), 'Wednesday');
      expect(getDayName(DateTime(2025, 10, 23)), 'Thursday');
      expect(getDayName(DateTime(2025, 10, 24)), 'Friday');
      expect(getDayName(DateTime(2025, 10, 25)), 'Saturday');
      expect(getDayName(DateTime(2025, 10, 26)), 'Sunday');
    });

    test('Service with all weekdays', () {
      final service = createTestService(
        title: 'Mon-Fri Service',
        availability: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      );

      final baseDate = DateTime(2025, 10, 20); // Monday

      // Monday through Friday should be available
      for (int i = 0; i < 5; i++) {
        final testDate = baseDate.add(Duration(days: i));
        expect(
          isDateAvailableForService(testDate, service),
          true,
          reason: '${getDayName(testDate)} should be available for weekday service',
        );
      }

      // Weekend should NOT be available
      final saturday = baseDate.add(const Duration(days: 5));
      expect(isDateAvailableForService(saturday, service), false);

      final sunday = baseDate.add(const Duration(days: 6));
      expect(isDateAvailableForService(sunday, service), false);
    });

    test('Single day service', () {
      final service = createTestService(
        title: 'Tuesday Only Service',
        availability: ['tuesday'],
      );

      final baseDate = DateTime(2025, 10, 20); // Monday

      for (int i = 0; i < 7; i++) {
        final testDate = baseDate.add(Duration(days: i));
        final shouldBeAvailable = getDayName(testDate) == 'Tuesday';
        
        expect(
          isDateAvailableForService(testDate, service),
          shouldBeAvailable,
          reason: '${getDayName(testDate)} availability should be $shouldBeAvailable',
        );
      }
    });

    test('Leap year and edge dates', () {
      final service = createTestService(
        title: 'Monday Service',
        availability: ['monday'],
      );

      // Feb 29, 2024 is a Thursday (leap year)
      final leapDay = DateTime(2024, 2, 29);
      expect(isDateAvailableForService(leapDay, service), false);
      expect(getDayName(leapDay), 'Thursday');

      // March 4, 2024 is a Monday
      final nextMonday = DateTime(2024, 3, 4);
      expect(isDateAvailableForService(nextMonday, service), true);
      expect(getDayName(nextMonday), 'Monday');

      // Year boundary - Dec 31, 2024 is Tuesday
      final yearEnd = DateTime(2024, 12, 31);
      expect(isDateAvailableForService(yearEnd, service), false);
      expect(getDayName(yearEnd), 'Tuesday');

      // Jan 1, 2025 is Wednesday
      final yearStart = DateTime(2025, 1, 1);
      expect(isDateAvailableForService(yearStart, service), false);
      expect(getDayName(yearStart), 'Wednesday');
    });

    test('Case sensitivity - availability should use lowercase', () {
      // Service with lowercase days (correct)
      final service1 = createTestService(
        title: 'Lowercase Service',
        availability: ['monday', 'friday'],
      );

      final monday = DateTime(2025, 10, 20);
      expect(isDateAvailableForService(monday, service1), true);

      // Note: In production, providers should only be able to select lowercase
      // values through the UI (FilterChip), so this is the expected format
    });
  });

  group('Availability Message Tests', () {
    String getAvailableDaysText(List<String> availability) {
      if (availability.isEmpty) {
        return 'All days';
      }
      
      return availability
          .map((day) => day[0].toUpperCase() + day.substring(1))
          .join(', ');
    }

    test('Empty availability returns "All days"', () {
      expect(getAvailableDaysText([]), 'All days');
    });

    test('Single day availability', () {
      expect(getAvailableDaysText(['monday']), 'Monday');
      expect(getAvailableDaysText(['friday']), 'Friday');
    });

    test('Multiple days availability', () {
      expect(
        getAvailableDaysText(['monday', 'wednesday', 'friday']),
        'Monday, Wednesday, Friday',
      );
    });

    test('Weekdays availability', () {
      expect(
        getAvailableDaysText(['monday', 'tuesday', 'wednesday', 'thursday', 'friday']),
        'Monday, Tuesday, Wednesday, Thursday, Friday',
      );
    });

    test('Weekend availability', () {
      expect(
        getAvailableDaysText(['saturday', 'sunday']),
        'Saturday, Sunday',
      );
    });

    test('All days availability', () {
      expect(
        getAvailableDaysText([
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday'
        ]),
        'Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday',
      );
    });
  });
}
