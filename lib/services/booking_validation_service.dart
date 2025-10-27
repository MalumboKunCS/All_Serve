import '../models/booking.dart';
import '../utils/app_logger.dart';

/// Service for validating booking operations and business rules
class BookingValidationService {
  /// Validates booking creation request
  /// 
  /// Business Rules:
  /// - Booking must be at least 2 hours in future
  /// - Duration must be between 15 minutes and 8 hours
  /// - Price must be positive
  /// - Scheduled time must be within 1 year
  static ValidationResult validateBookingCreation({
    required DateTime scheduledAt,
    required int durationMinutes,
    required double estimatedPrice,
    String? timezone,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Rule 1: Booking must be at least 2 hours in future
    final now = DateTime.now();
    final minimumAdvanceTime = now.add(const Duration(hours: 2));
    if (scheduledAt.isBefore(minimumAdvanceTime)) {
      errors.add('Booking must be scheduled at least 2 hours in advance');
    }

    // Rule 2: Duration must be realistic (15 min - 8 hours)
    if (durationMinutes < 15) {
      errors.add('Booking duration must be at least 15 minutes');
    }
    if (durationMinutes > 480) { // 8 hours
      errors.add('Booking duration cannot exceed 8 hours');
    }

    // Rule 3: Price must be positive
    if (estimatedPrice <= 0) {
      errors.add('Booking price must be greater than 0');
    }

    // Rule 4: Scheduled time must be within reasonable future (not more than 1 year)
    final maxFutureTime = now.add(const Duration(days: 365));
    if (scheduledAt.isAfter(maxFutureTime)) {
      errors.add('Booking cannot be scheduled more than 1 year in advance');
    }

    // Rule 5: Scheduled time must not be in the past
    if (scheduledAt.isBefore(now)) {
      errors.add('Cannot schedule booking in the past');
    }

    // Warning: Very short notice bookings (< 4 hours)
    final shortNoticeTime = now.add(const Duration(hours: 4));
    if (scheduledAt.isBefore(shortNoticeTime) && scheduledAt.isAfter(minimumAdvanceTime)) {
      warnings.add('Short notice booking - provider may not be available');
    }

    // Warning: Very long duration (> 4 hours)
    if (durationMinutes > 240) {
      warnings.add('Long duration booking - consider breaking into multiple sessions');
    }

    AppLogger.debug(
      'Booking validation: ${errors.isEmpty ? "PASSED" : "FAILED"} - '
      'Errors: ${errors.length}, Warnings: ${warnings.length}'
    );

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validates booking state transition
  /// 
  /// Allowed transitions:
  /// - pending -> accepted, rejected, cancelled
  /// - accepted -> inProgress, cancelled, rescheduled
  /// - inProgress -> completed, cancelled, pendingCustomerConfirmation
  /// - rescheduled -> accepted, cancelled
  /// - pendingCustomerConfirmation -> completed, cancelled
  static bool canTransitionTo({
    required BookingStatus currentStatus,
    required BookingStatus newStatus,
  }) {
    // Cannot transition to same status
    if (currentStatus == newStatus) {
      AppLogger.warning('Cannot transition to same status: $currentStatus');
      return false;
    }

    // Define allowed transitions
    const allowedTransitions = {
      BookingStatus.pending: [
        BookingStatus.accepted,
        BookingStatus.rejected,
        BookingStatus.cancelled,
      ],
      BookingStatus.accepted: [
        BookingStatus.inProgress,
        BookingStatus.cancelled,
        BookingStatus.rescheduled,
      ],
      BookingStatus.inProgress: [
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.pendingCustomerConfirmation, // Added this transition
      ],
      BookingStatus.rescheduled: [
        BookingStatus.accepted,
        BookingStatus.cancelled,
      ],
      BookingStatus.pendingCustomerConfirmation: [ // Added this status
        BookingStatus.completed,
        BookingStatus.cancelled,
      ],
      // Terminal states - no transitions allowed
      BookingStatus.completed: [],
      BookingStatus.cancelled: [],
      BookingStatus.rejected: [],
    };

    final allowed = allowedTransitions[currentStatus] ?? [];
    final canTransition = allowed.contains(newStatus);

    if (!canTransition) {
      AppLogger.warning(
        'Invalid state transition: $currentStatus -> $newStatus'
      );
    }

    return canTransition;
  }

  /// Validates if booking can be cancelled
  static ValidationResult validateCancellation({
    required Booking booking,
    required String userId,
  }) {
    final errors = <String>[];

    // Rule 1: Only customer or provider can cancel
    if (booking.customerId != userId && booking.providerId != userId) {
      errors.add('You do not have permission to cancel this booking');
    }

    // Rule 2: Cannot cancel completed bookings
    if (booking.isCompleted) {
      errors.add('Cannot cancel a completed booking');
    }

    // Rule 3: Cannot cancel already cancelled bookings
    if (booking.isCancelled) {
      errors.add('Booking is already cancelled');
    }

    // Rule 4: Cannot cancel rejected bookings
    if (booking.isRejected) {
      errors.add('Cannot cancel a rejected booking');
    }

    // Rule 5: Check if status allows cancellation
    if (!booking.canBeCancelled) {
      errors.add('Booking status does not allow cancellation');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validates if booking can be rescheduled
  static ValidationResult validateReschedule({
    required Booking booking,
    required DateTime newScheduledAt,
    required String userId,
  }) {
    final errors = <String>[];

    // Rule 1: Only customer or provider can reschedule
    if (booking.customerId != userId && booking.providerId != userId) {
      errors.add('You do not have permission to reschedule this booking');
    }

    // Rule 2: Check if status allows rescheduling
    if (!booking.canBeRescheduled) {
      errors.add('Booking status does not allow rescheduling');
    }

    // Rule 3: New time must be different from current time
    if (newScheduledAt.isAtSameMomentAs(booking.scheduledAt)) {
      errors.add('New scheduled time must be different from current time');
    }

    // Rule 4: Validate new time using creation rules
    final newTimeValidation = validateBookingCreation(
      scheduledAt: newScheduledAt,
      durationMinutes: booking.durationMinutes,
      estimatedPrice: booking.estimatedPrice,
    );

    if (!newTimeValidation.isValid) {
      errors.addAll(newTimeValidation.errors);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validates review eligibility for a booking
  /// 
  /// Rules:
  /// - Customer must own the booking
  /// - Booking must be completed
  /// - Review window is 30 days after completion
  /// - Cannot review if already reviewed
  static ValidationResult validateReviewEligibility({
    required Booking booking,
    required String customerId,
  }) {
    final errors = <String>[];

    // Rule 1: Customer must own the booking
    if (booking.customerId != customerId) {
      errors.add('You can only review your own bookings');
    }

    // Rule 2: Booking must be completed
    if (!booking.isCompleted) {
      errors.add('You can only review completed bookings');
    }

    // Rule 3: Review window - 30 days after completion
    if (booking.completedAt != null) {
      final reviewDeadline = booking.completedAt!.add(const Duration(days: 30));
      if (DateTime.now().isAfter(reviewDeadline)) {
        errors.add('Review window has expired (30 days after completion)');
      }
    } else if (booking.isCompleted) {
      // Completed but no completion date - allow review
      errors.add('Booking completion date not found');
    }

    // Rule 4: Cannot review if already reviewed
    if (booking.hasReview) {
      errors.add('You have already reviewed this booking');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validates review data
  static ValidationResult validateReviewData({
    required double rating,
    required String comment,
    String? title,
  }) {
    final errors = <String>[];

    // Rule 1: Rating must be between 1 and 5
    if (rating < 1.0 || rating > 5.0) {
      errors.add('Rating must be between 1 and 5');
    }

    // Rule 2: Comment cannot be empty
    if (comment.trim().isEmpty) {
      errors.add('Review comment cannot be empty');
    }

    // Rule 3: Comment max length (500 characters)
    if (comment.length > 500) {
      errors.add('Review comment cannot exceed 500 characters');
    }

    // Rule 4: Comment min length (10 characters for quality)
    if (comment.trim().length < 10) {
      errors.add('Review comment must be at least 10 characters');
    }

    // Rule 5: Title max length if provided (100 characters)
    if (title != null && title.length > 100) {
      errors.add('Review title cannot exceed 100 characters');
    }

    // Rule 6: Basic profanity check (simple implementation)
    if (_containsProfanity(comment) || (title != null && _containsProfanity(title))) {
      errors.add('Review contains inappropriate language');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Basic profanity filter (simple implementation)
  /// In production, use a proper profanity filter library
  static bool _containsProfanity(String text) {
    // Simple check - in production use a proper library
    final lowerText = text.toLowerCase();
    const badWords = ['spam', 'scam']; // Add actual profanity list
    return badWords.any((word) => lowerText.contains(word));
  }

  /// Validates payment status transition
  static bool canTransitionPaymentStatus({
    required PaymentStatus? currentStatus,
    required PaymentStatus newStatus,
  }) {
    if (currentStatus == null) {
      // From null, can only go to unpaid or pending
      return newStatus == PaymentStatus.unpaid || newStatus == PaymentStatus.pending;
    }

    if (currentStatus == newStatus) {
      return false; // Cannot transition to same status
    }

    // Define allowed payment transitions
    const allowedTransitions = {
      PaymentStatus.unpaid: [
        PaymentStatus.pending,
        PaymentStatus.paid,
      ],
      PaymentStatus.pending: [
        PaymentStatus.paid,
        PaymentStatus.failed,
        PaymentStatus.unpaid,
      ],
      PaymentStatus.paid: [
        PaymentStatus.refunded,
      ],
      PaymentStatus.failed: [
        PaymentStatus.pending,
        PaymentStatus.unpaid,
      ],
      PaymentStatus.refunded: [], // Terminal state
    };

    final allowed = allowedTransitions[currentStatus] ?? [];
    return allowed.contains(newStatus);
  }
}

/// Result of a validation operation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Get first error message
  String? get firstError => errors.isNotEmpty ? errors.first : null;

  /// Get all errors as a single string
  String get errorMessage => errors.join('; ');

  /// Get all warnings as a single string
  String get warningMessage => warnings.join('; ');

  /// Get combined message with errors and warnings
  String get fullMessage {
    final messages = <String>[];
    if (errors.isNotEmpty) {
      messages.add('Errors: ${errorMessage}');
    }
    if (warnings.isNotEmpty) {
      messages.add('Warnings: ${warningMessage}');
    }
    return messages.join(' | ');
  }

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, errors: $errors, warnings: $warnings)';
  }
}
