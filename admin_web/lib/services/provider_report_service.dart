import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared/shared.dart' as shared;
import '../utils/app_logger.dart';

class ProviderReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new provider report
  static Future<String?> createReport({
    required String providerId,
    required String reportedBy,
    required String reporterName,
    required String reporterEmail,
    required shared.ReportType reportType,
    required String title,
    required String description,
    int priority = 1,
    String? bookingId,
    List<String> attachments = const [],
  }) async {
    try {
      final reportData = {
        'providerId': providerId,
        'reportedBy': reportedBy,
        'reporterName': reporterName,
        'reporterEmail': reporterEmail,
        'reportType': reportType.name,
        'title': title,
        'description': description,
        'status': shared.ReportStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'priority': priority,
        'bookingId': bookingId,
        'attachments': attachments,
      };

      final docRef = await _firestore.collection('provider_reports').add(reportData);
      
      // Log the report creation
      await _logReportAction(
        docRef.id,
        'created',
        'New report created: $title',
      );

      return docRef.id;
    } catch (e) {
      AppLogger.info('Error creating provider report: $e');
      return null;
    }
  }

  /// Get all reports for a specific provider
  static Future<List<shared.ProviderReport>> getReportsForProvider(String providerId) async {
    try {
      final snapshot = await _firestore
          .collection('provider_reports')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return shared.ProviderReport.fromFirestore(doc);
      }).toList();
    } catch (e) {
      AppLogger.info('Error getting reports for provider: $e');
      return [];
    }
  }

  /// Get all reports with optional filtering
  static Future<List<shared.ProviderReport>> getAllReports({
    shared.ReportStatus? status,
    shared.ReportType? reportType,
    int? priority,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('provider_reports')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (reportType != null) {
        query = query.where('reportType', isEqualTo: reportType.name);
      }

      if (priority != null) {
        query = query.where('priority', isEqualTo: priority);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        return shared.ProviderReport.fromFirestore(doc);
      }).toList();
    } catch (e) {
      AppLogger.info('Error getting all reports: $e');
      return [];
    }
  }

  /// Get report by ID
  static Future<shared.ProviderReport?> getReportById(String reportId) async {
    try {
      final doc = await _firestore.collection('provider_reports').doc(reportId).get();
      
      if (doc.exists) {
        return shared.ProviderReport.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.info('Error getting report by ID: $e');
      return null;
    }
  }

  /// Update report status
  static Future<bool> updateReportStatus(
    String reportId,
    shared.ReportStatus status, {
    String? adminNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'resolvedBy': shared.AuthService().currentUser?.uid,
      };

      if (status == shared.ReportStatus.resolved || status == shared.ReportStatus.dismissed) {
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
      }

      if (adminNotes != null && adminNotes.isNotEmpty) {
        updateData['adminNotes'] = adminNotes;
      }

      await _firestore.collection('provider_reports').doc(reportId).update(updateData);

      // Log the status update
      await _logReportAction(
        reportId,
        'status_updated',
        'Report status updated to: ${status.name}',
      );

      return true;
    } catch (e) {
      AppLogger.info('Error updating report status: $e');
      return false;
    }
  }

  /// Add admin notes to report
  static Future<bool> addAdminNotes(String reportId, String notes) async {
    try {
      await _firestore.collection('provider_reports').doc(reportId).update({
        'adminNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': shared.AuthService().currentUser?.uid,
      });

      // Log the notes addition
      await _logReportAction(
        reportId,
        'notes_added',
        'Admin notes added to report',
      );

      return true;
    } catch (e) {
      AppLogger.info('Error adding admin notes: $e');
      return false;
    }
  }

  /// Get reports statistics
  static Future<Map<String, int>> getReportStats() async {
    try {
      final snapshot = await _firestore.collection('provider_reports').get();
      final reports = snapshot.docs.map((doc) {
        return shared.ProviderReport.fromFirestore(doc);
      }).toList();

      final stats = <String, int>{
        'total': reports.length,
        'pending': 0,
        'investigating': 0,
        'resolved': 0,
        'dismissed': 0,
      };

      for (final report in reports) {
        switch (report.status) {
          case shared.ReportStatus.pending:
            stats['pending'] = stats['pending']! + 1;
            break;
          case shared.ReportStatus.investigating:
            stats['investigating'] = stats['investigating']! + 1;
            break;
          case shared.ReportStatus.resolved:
            stats['resolved'] = stats['resolved']! + 1;
            break;
          case shared.ReportStatus.dismissed:
            stats['dismissed'] = stats['dismissed']! + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      AppLogger.info('Error getting report stats: $e');
      return {};
    }
  }

  /// Get reports by priority
  static Future<List<shared.ProviderReport>> getHighPriorityReports() async {
    try {
      final snapshot = await _firestore
          .collection('provider_reports')
          .where('priority', isGreaterThanOrEqualTo: 3)
          .where('status', whereIn: ['pending', 'investigating'])
          .orderBy('priority', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        return shared.ProviderReport.fromFirestore(doc);
      }).toList();
    } catch (e) {
      AppLogger.info('Error getting high priority reports: $e');
      return [];
    }
  }

  /// Get reports stream for real-time updates
  static Stream<List<shared.ProviderReport>> getReportsStream({
    shared.ReportStatus? status,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('provider_reports')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return shared.ProviderReport.fromFirestore(doc);
      }).toList();
    });
  }

  /// Delete report (soft delete by marking as dismissed)
  static Future<bool> deleteReport(String reportId) async {
    try {
      await _firestore.collection('provider_reports').doc(reportId).update({
        'status': shared.ReportStatus.dismissed.name,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': shared.AuthService().currentUser?.uid,
        'adminNotes': 'Report deleted by admin',
      });

      // Log the deletion
      await _logReportAction(
        reportId,
        'deleted',
        'Report deleted by admin',
      );

      return true;
    } catch (e) {
      AppLogger.info('Error deleting report: $e');
      return false;
    }
  }

  /// Log report action
  static Future<void> _logReportAction(
    String reportId,
    String action,
    String description,
  ) async {
    try {
      await _firestore.collection('report_logs').add({
        'reportId': reportId,
        'action': action,
        'description': description,
        'adminId': shared.AuthService().currentUser?.uid,
        'adminName': shared.AuthService().currentUser?.name ?? 'Unknown Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.info('Error logging report action: $e');
    }
  }

  /// Get report action logs
  static Future<List<Map<String, dynamic>>> getReportLogs(String reportId) async {
    try {
      final snapshot = await _firestore
          .collection('report_logs')
          .where('reportId', isEqualTo: reportId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      AppLogger.info('Error getting report logs: $e');
      return [];
    }
  }
}
