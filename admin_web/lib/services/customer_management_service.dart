import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;

class CustomerManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all customers stream for real-time updates
  static Stream<List<shared.User>> getCustomersStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return shared.User.fromFirestore(doc);
      }).toList();
    });
  }

  /// Get all customers (one-time fetch)
  static Future<List<shared.User>> getAllCustomers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return shared.User.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting all customers: $e');
      return [];
    }
  }

  /// Get customer by ID
  static Future<shared.User?> getCustomerById(String customerId) async {
    try {
      final doc = await _firestore.collection('users').doc(customerId).get();
      
      if (doc.exists) {
        final user = shared.User.fromFirestore(doc);
        return user.role == 'customer' ? user : null;
      }
      return null;
    } catch (e) {
      print('Error getting customer by ID: $e');
      return null;
    }
  }

  /// Suspend customer account
  static Future<bool> suspendCustomer(String customerId, {String? reason}) async {
    try {
      await _firestore.collection('users').doc(customerId).update({
        'status': 'suspended',
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspendedBy': shared.AuthService().currentUser?.uid,
        'suspensionReason': reason,
      });

      // Log the action
      await _logCustomerAction(
        customerId,
        'suspended',
        'Customer account suspended${reason != null ? ': $reason' : ''}',
      );

      // Send notification to customer
      await shared.NotificationService.sendNotificationToUser(
        userId: customerId,
        title: 'Account Suspended',
        body: 'Your account has been suspended. Please contact support for more information.',
        data: {
          'type': 'account_suspended',
          'reason': reason ?? 'No reason provided',
        },
      );

      return true;
    } catch (e) {
      print('Error suspending customer: $e');
      return false;
    }
  }

  /// Activate customer account
  static Future<bool> activateCustomer(String customerId) async {
    try {
      await _firestore.collection('users').doc(customerId).update({
        'status': 'active',
        'activatedAt': FieldValue.serverTimestamp(),
        'activatedBy': shared.AuthService().currentUser?.uid,
        'suspensionReason': null,
      });

      // Log the action
      await _logCustomerAction(
        customerId,
        'activated',
        'Customer account activated',
      );

      // Send notification to customer
      await shared.NotificationService.sendNotificationToUser(
        userId: customerId,
        title: 'Account Activated',
        body: 'Your account has been activated. You can now make bookings again.',
        data: {
          'type': 'account_activated',
        },
      );

      return true;
    } catch (e) {
      print('Error activating customer: $e');
      return false;
    }
  }

  /// Delete customer account
  static Future<bool> deleteCustomer(String customerId) async {
    try {
      // First, get customer data for logging
      await getCustomerById(customerId);
      
      // Delete the user document
      await _firestore.collection('users').doc(customerId).delete();

      // Log the action
      await _logCustomerAction(
        customerId,
        'deleted',
        'Customer account permanently deleted',
      );

      // TODO: Consider what to do with related data (bookings, reviews, etc.)
      // For now, we'll just delete the user document
      // In a production system, you might want to:
      // - Anonymize bookings and reviews
      // - Archive data for compliance
      // - Notify related providers

      return true;
    } catch (e) {
      print('Error deleting customer: $e');
      return false;
    }
  }

  /// Flag customer for suspicious activity
  static Future<bool> flagCustomer(String customerId, String reason, String description) async {
    try {
      await _firestore.collection('customer_reports').add({
        'customerId': customerId,
        'reportedBy': shared.AuthService().currentUser?.uid,
        'reporterName': shared.AuthService().currentUser?.name ?? 'Admin',
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logCustomerAction(
        customerId,
        'flagged',
        'Customer flagged: $reason - $description',
      );

      return true;
    } catch (e) {
      print('Error flagging customer: $e');
      return false;
    }
  }

  /// Get customer analytics
  static Future<Map<String, dynamic>> getCustomerAnalytics(String customerId) async {
    try {
      // Get customer's bookings
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: customerId)
          .get();

      final bookings = bookingsSnapshot.docs.map((doc) {
        return shared.Booking.fromFirestore(doc);
      }).toList();

      // Calculate stats
      final totalBookings = bookings.length;
      final completedBookings = bookings.where((b) => b.status == 'completed').length;
      final cancelledBookings = bookings.where((b) => b.status == 'cancelled').length;
      final pendingBookings = bookings.where((b) => b.status == 'pending').length;

      // Get customer's reviews
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('customerId', isEqualTo: customerId)
          .get();

      final totalReviews = reviewsSnapshot.docs.length;

      // Get recent activity (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentBookings = bookings.where((b) => b.requestedAt.isAfter(thirtyDaysAgo)).length;

      return {
        'totalBookings': totalBookings,
        'completedBookings': completedBookings,
        'cancelledBookings': cancelledBookings,
        'pendingBookings': pendingBookings,
        'totalReviews': totalReviews,
        'recentBookings': recentBookings,
        'lastBookingDate': bookings.isNotEmpty 
            ? bookings.map((b) => b.requestedAt).reduce((a, b) => a.isAfter(b) ? a : b)
            : null,
      };
    } catch (e) {
      print('Error getting customer analytics: $e');
      return {};
    }
  }

  /// Get customer's booking history
  static Future<List<shared.Booking>> getCustomerBookings(String customerId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: customerId)
          .orderBy('requestedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return shared.Booking.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting customer bookings: $e');
      return [];
    }
  }

  /// Get customer's reviews
  static Future<List<shared.Review>> getCustomerReviews(String customerId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return shared.Review.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting customer reviews: $e');
      return [];
    }
  }

  /// Get flagged customers
  static Future<List<Map<String, dynamic>>> getFlaggedCustomers() async {
    try {
      final snapshot = await _firestore
          .collection('customer_reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting flagged customers: $e');
      return [];
    }
  }

  /// Get customer action logs
  static Future<List<Map<String, dynamic>>> getCustomerLogs(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('customer_logs')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting customer logs: $e');
      return [];
    }
  }

  /// Get customer growth statistics
  static Future<Map<String, dynamic>> getCustomerGrowthStats() async {
    try {
      final now = DateTime.now();
      final lastMonth = now.subtract(const Duration(days: 30));
      final lastWeek = now.subtract(const Duration(days: 7));

      // Get total customers
      final totalCustomersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();

      // Get customers from last month
      final monthlyCustomersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .get();

      // Get customers from last week
      final weeklyCustomersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeek))
          .get();

      // Get active customers (made bookings in last 30 days)
      final activeCustomersSnapshot = await _firestore
          .collection('bookings')
          .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .get();

      final activeCustomerIds = activeCustomersSnapshot.docs
          .map((doc) => doc.data()['customerId'])
          .toSet()
          .length;

      return {
        'totalCustomers': totalCustomersSnapshot.docs.length,
        'monthlyNewCustomers': monthlyCustomersSnapshot.docs.length,
        'weeklyNewCustomers': weeklyCustomersSnapshot.docs.length,
        'activeCustomers': activeCustomerIds,
        'inactiveCustomers': totalCustomersSnapshot.docs.length - activeCustomerIds,
      };
    } catch (e) {
      print('Error getting customer growth stats: $e');
      return {};
    }
  }

  /// Log customer action
  static Future<void> _logCustomerAction(
    String customerId,
    String action,
    String description,
  ) async {
    try {
      await _firestore.collection('customer_logs').add({
        'customerId': customerId,
        'action': action,
        'description': description,
        'adminId': shared.AuthService().currentUser?.uid,
        'adminName': shared.AuthService().currentUser?.name ?? 'Unknown Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging customer action: $e');
    }
  }
}
