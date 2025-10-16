import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

class VerificationCleanupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Clean up duplicate verification queue entries
  /// This should be run once to fix existing data
  static Future<void> cleanupDuplicateVerificationEntries() async {
    try {
      AppLogger.info('VerificationCleanupService: Starting cleanup of duplicate verification entries...');
      
      // Get all verification queue documents
      final snapshot = await _firestore.collection('verification_queue').get();
      AppLogger.info('VerificationCleanupService: Found ${snapshot.docs.length} total verification entries');
      
      // Group by providerId
      final Map<String, List<QueryDocumentSnapshot>> groupedByProvider = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final providerId = data?['providerId'] as String?;
        if (providerId != null) {
          groupedByProvider.putIfAbsent(providerId, () => []).add(doc);
        }
      }
      
      AppLogger.info('VerificationCleanupService: Found ${groupedByProvider.length} unique providers');
      
      int totalDeleted = 0;
      int totalFixed = 0;
      
      // Process each provider
      for (final entry in groupedByProvider.entries) {
        final providerId = entry.key;
        final docs = entry.value;
        
        if (docs.length > 1) {
          AppLogger.info('VerificationCleanupService: Provider $providerId has ${docs.length} entries, cleaning up...');
          
          // Sort by submittedAt (most recent first)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTime = aData?['submittedAt'] as Timestamp?;
            final bTime = bData?['submittedAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });
          
          // Keep the most recent entry, delete the rest
          final keepDoc = docs.first;
          final deleteDocs = docs.skip(1).toList();
          
          // Fix the kept document if needed
          final keepData = keepDoc.data() as Map<String, dynamic>? ?? {};
          final updates = <String, dynamic>{};
          
          // Ensure ownerUid is set
          if (keepData['ownerUid'] == null) {
            // Try to get ownerUid from provider document
            try {
              final providerDoc = await _firestore.collection('providers').doc(providerId).get();
              if (providerDoc.exists) {
                final providerData = providerDoc.data() as Map<String, dynamic>;
                final ownerUid = providerData['ownerUid'] as String?;
                if (ownerUid != null) {
                  updates['ownerUid'] = ownerUid;
                  AppLogger.info('VerificationCleanupService: Fixed ownerUid for ${keepDoc.id}');
                  totalFixed++;
                }
              }
            } catch (e) {
              AppLogger.info('VerificationCleanupService: Error getting provider data for $providerId: $e');
            }
          }
          
          // Ensure docs field exists
          if (!keepData.containsKey('docs')) {
            updates['docs'] = {};
            AppLogger.info('VerificationCleanupService: Added docs field for ${keepDoc.id}');
            totalFixed++;
          }
          
          // Update the kept document if needed
          if (updates.isNotEmpty) {
            await keepDoc.reference.update(updates);
          }
          
          // Delete duplicate entries
          for (var doc in deleteDocs) {
            await doc.reference.delete();
            totalDeleted++;
            AppLogger.info('VerificationCleanupService: Deleted duplicate entry ${doc.id}');
          }
        } else if (docs.length == 1) {
          // Single entry - just fix it if needed
          final doc = docs.first;
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final updates = <String, dynamic>{};
          
          // Ensure ownerUid is set
          if (data['ownerUid'] == null) {
            try {
              final providerDoc = await _firestore.collection('providers').doc(providerId).get();
              if (providerDoc.exists) {
                final providerData = providerDoc.data() as Map<String, dynamic>;
                final ownerUid = providerData['ownerUid'] as String?;
                if (ownerUid != null) {
                  updates['ownerUid'] = ownerUid;
                  AppLogger.info('VerificationCleanupService: Fixed ownerUid for ${doc.id}');
                  totalFixed++;
                }
              }
            } catch (e) {
              AppLogger.info('VerificationCleanupService: Error getting provider data for $providerId: $e');
            }
          }
          
          // Ensure docs field exists
          if (!data.containsKey('docs')) {
            updates['docs'] = {};
            AppLogger.info('VerificationCleanupService: Added docs field for ${doc.id}');
            totalFixed++;
          }
          
          // Update the document if needed
          if (updates.isNotEmpty) {
            await doc.reference.update(updates);
          }
        }
      }
      
      AppLogger.info('VerificationCleanupService: Cleanup completed!');
      AppLogger.info('VerificationCleanupService: Deleted $totalDeleted duplicate entries');
      AppLogger.info('VerificationCleanupService: Fixed $totalFixed entries');
      
    } catch (e) {
      AppLogger.info('VerificationCleanupService: Error during cleanup: $e');
      rethrow;
    }
  }
}
