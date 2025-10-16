import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;
import '../utils/app_logger.dart';

class ProviderManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Suspend or unsuspend a provider
  static Future<bool> suspendProvider(String providerId, bool suspend) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'status': suspend ? 'suspended' : 'active',
        'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
        'suspendedBy': suspend ? shared.AuthService().currentUser?.uid : null,
      });

      // Log the action
      await _logProviderAction(
        providerId,
        suspend ? 'suspended' : 'unsuspended',
        'Provider ${suspend ? 'suspended' : 'unsuspended'} by admin',
      );

      return true;
    } catch (e) {
      AppLogger.info('Error suspending provider: $e');
      return false;
    }
  }

  /// Promote provider to featured status
  static Future<bool> promoteProvider(String providerId, bool promote) async {
    try {
      await _firestore.collection('providers').doc(providerId).update({
        'featured': promote,
        'featuredAt': promote ? FieldValue.serverTimestamp() : null,
        'featuredBy': promote ? shared.AuthService().currentUser?.uid : null,
      });

      // Log the action
      await _logProviderAction(
        providerId,
        promote ? 'promoted' : 'unpromoted',
        'Provider ${promote ? 'promoted to' : 'removed from'} featured status',
      );

      return true;
    } catch (e) {
      AppLogger.info('Error promoting provider: $e');
      return false;
    }
  }

  /// Reset provider password
  static Future<bool> resetProviderPassword(String providerId) async {
    try {
      // TODO: Implement actual password reset logic
      // This would typically involve:
      // 1. Generating a temporary password
      // 2. Sending email to provider
      // 3. Logging the action
      
      await _logProviderAction(
        providerId,
        'password_reset',
        'Password reset requested by admin',
      );

      return true;
    } catch (e) {
      AppLogger.info('Error resetting password: $e');
      return false;
    }
  }

  /// Delete provider permanently
  static Future<bool> deleteProvider(String providerId) async {
    try {
      // First, log the action
      await _logProviderAction(
        providerId,
        'deleted',
        'Provider permanently deleted by admin',
      );

      // Delete the provider document
      await _firestore.collection('providers').doc(providerId).delete();

      // TODO: Consider soft delete instead of hard delete
      // You might want to move to a 'deleted_providers' collection
      // or add a 'deleted' flag instead of actually deleting

      return true;
    } catch (e) {
      AppLogger.info('Error deleting provider: $e');
      return false;
    }
  }

  /// Get provider analytics
  static Future<Map<String, dynamic>> getProviderAnalytics(String providerId) async {
    try {
      // Get booking statistics
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .get();

      final bookings = bookingsSnapshot.docs;
      final totalBookings = bookings.length;
      final completedBookings = bookings.where((doc) {
        final data = doc.data();
        return data['status'] == 'completed';
      }).length;
      final cancelledBookings = bookings.where((doc) {
        final data = doc.data();
        return data['status'] == 'cancelled';
      }).length;

      // Get reviews
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .get();

      final reviews = reviewsSnapshot.docs;
      final totalReviews = reviews.length;
      final averageRating = totalReviews > 0
          ? reviews.fold<double>(0, (sum, doc) {
              final data = doc.data();
              return sum + (data['rating'] as num).toDouble();
            }) / totalReviews
          : 0.0;

      // Get recent activity (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentBookings = bookings.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(thirtyDaysAgo);
      }).length;

      return {
        'totalBookings': totalBookings,
        'completedBookings': completedBookings,
        'cancelledBookings': cancelledBookings,
        'completionRate': totalBookings > 0 ? (completedBookings / totalBookings) * 100 : 0.0,
        'cancellationRate': totalBookings > 0 ? (cancelledBookings / totalBookings) * 100 : 0.0,
        'totalReviews': totalReviews,
        'averageRating': averageRating,
        'recentBookings': recentBookings,
      };
    } catch (e) {
      AppLogger.info('Error getting provider analytics: $e');
      return {};
    }
  }

  /// Get flagged providers
  static Future<List<Map<String, dynamic>>> getFlaggedProviders() async {
    try {
      // Get providers with high cancellation rates or low ratings
      final providersSnapshot = await _firestore
          .collection('providers')
          .where('verified', isEqualTo: true)
          .get();

      final flaggedProviders = <Map<String, dynamic>>[];

      for (final doc in providersSnapshot.docs) {
        final providerData = doc.data();
        final providerId = doc.id;
        
        // Get analytics for this provider
        final analytics = await getProviderAnalytics(providerId);
        
        // Flag providers based on criteria
        final cancellationRate = analytics['cancellationRate'] ?? 0.0;
        final averageRating = analytics['averageRating'] ?? 5.0;
        final totalReviews = analytics['totalReviews'] ?? 0;
        
        if (cancellationRate > 30.0 || (averageRating < 2.0 && totalReviews >= 3)) {
          flaggedProviders.add({
            'providerId': providerId,
            'providerData': providerData,
            'analytics': analytics,
            'reason': _getFlagReason(cancellationRate, averageRating, totalReviews),
          });
        }
      }

      return flaggedProviders;
    } catch (e) {
      AppLogger.info('Error getting flagged providers: $e');
      return [];
    }
  }

  /// Get provider action logs
  static Future<List<Map<String, dynamic>>> getProviderLogs(String providerId) async {
    try {
      final logsSnapshot = await _firestore
          .collection('provider_logs')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return logsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      AppLogger.info('Error getting provider logs: $e');
      return [];
    }
  }

  /// Log provider action
  static Future<void> _logProviderAction(
    String providerId,
    String action,
    String description,
  ) async {
    try {
      await _firestore.collection('provider_logs').add({
        'providerId': providerId,
        'action': action,
        'description': description,
        'adminId': shared.AuthService().currentUser?.uid,
        'adminName': shared.AuthService().currentUser?.name ?? 'Unknown Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.info('Error logging provider action: $e');
    }
  }

  /// Get flag reason
  static String _getFlagReason(double cancellationRate, double averageRating, int totalReviews) {
    if (cancellationRate > 30.0 && averageRating < 2.0) {
      return 'High cancellation rate (${cancellationRate.toStringAsFixed(1)}%) and low rating (${averageRating.toStringAsFixed(1)}⭐)';
    } else if (cancellationRate > 30.0) {
      return 'High cancellation rate (${cancellationRate.toStringAsFixed(1)}%)';
    } else if (averageRating < 2.0 && totalReviews >= 3) {
      return 'Low rating (${averageRating.toStringAsFixed(1)}⭐) with ${totalReviews} reviews';
    }
    return 'Multiple issues detected';
  }

  /// Get all providers with analytics
  static Future<List<Map<String, dynamic>>> getAllProvidersWithAnalytics() async {
    try {
      final providersSnapshot = await _firestore
          .collection('providers')
          .where('verified', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'approved')
          .get();

      final providersWithAnalytics = <Map<String, dynamic>>[];

      for (final doc in providersSnapshot.docs) {
        final providerData = doc.data();
        final providerId = doc.id;
        
        // Get analytics for this provider
        final analytics = await getProviderAnalytics(providerId);
        
        providersWithAnalytics.add({
          'providerId': providerId,
          'providerData': providerData,
          'analytics': analytics,
        });
      }

      return providersWithAnalytics;
    } catch (e) {
      AppLogger.info('Error getting all providers with analytics: $e');
      return [];
    }
  }
}








