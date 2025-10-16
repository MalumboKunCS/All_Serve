import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import 'category_service.dart';

class VerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit provider for verification
  static Future<bool> submitForVerification({
    required String providerId,
    required String ownerUid,
    required Map<String, String> documents,
  }) async {
    try {
      AppLogger.info('VerificationService: submitForVerification called with providerId: $providerId, ownerUid: $ownerUid');
      
      // Update provider with verification status
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': 'pending',
        'visibleToCustomers': false,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Find existing verification queue entry
      AppLogger.info('VerificationService: Looking for existing verification queue entry with providerId: $providerId');
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('providerId', isEqualTo: providerId)
          .get();

      AppLogger.info('VerificationService: Query found ${queueQuery.docs.length} existing entries');
      
      if (queueQuery.docs.isNotEmpty) {
        // Get the most recent entry (should be only one, but just in case)
        final sortedDocs = queueQuery.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['submittedAt'] as Timestamp?;
            final bTime = b.data()['submittedAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });
        
        final latestDoc = sortedDocs.first;
        AppLogger.info('VerificationService: Updating existing verification queue entry ${latestDoc.id} with documents');
        
        // Update the existing entry with documents
        await latestDoc.reference.update({
          'ownerUid': ownerUid, // Ensure ownerUid is set
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
          'docs': documents, // Use 'docs' to match the model
          'adminRemarks': '',
        });
        
        // Delete any duplicate entries (keep only the latest one)
        if (sortedDocs.length > 1) {
          AppLogger.info('VerificationService: Deleting ${sortedDocs.length - 1} duplicate entries');
          for (int i = 1; i < sortedDocs.length; i++) {
            await sortedDocs[i].reference.delete();
          }
        }
      } else {
        // Create new entry
        AppLogger.info('VerificationService: Creating new verification queue entry with ownerUid: $ownerUid');
        final docRef = await _firestore.collection('verification_queue').add({
          'providerId': providerId,
          'ownerUid': ownerUid,
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
          'docs': documents, // Use 'docs' to match the model
          'adminRemarks': '',
          'reviewedAt': null,
          'reviewedBy': null,
        });
        AppLogger.info('VerificationService: Verification queue entry created with ID: ${docRef.id}');
      }

      return true;
    } catch (e) {
      AppLogger.info('Error submitting for verification: $e');
      return false;
    }
  }

  /// Approve provider verification
  static Future<bool> approveProvider({
    required String providerId,
    required String adminId,
    String? adminNotes,
  }) async {
    try {
      AppLogger.info('VerificationService: Approving provider: $providerId');
      
      // Use transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        // Get provider data
        final providerRef = _firestore.collection('providers').doc(providerId);
        final providerDoc = await transaction.get(providerRef);
        
        if (!providerDoc.exists) {
          throw Exception('Provider not found');
        }
        
        final providerData = providerDoc.data()!;
        final isCustomCategory = providerData['isCustomCategory'] ?? false;
        final customCategoryName = providerData['customCategoryName'] as String?;
        
        // Handle custom category logic
        if (isCustomCategory && customCategoryName != null) {
          AppLogger.info('VerificationService: Handling custom category: $customCategoryName');
          
          // Check if custom category already exists and is approved
          final existingCategory = await CategoryService.getCategoryByName(customCategoryName);
          
          if (existingCategory == null) {
            // Create the custom category as approved
            AppLogger.info('VerificationService: Creating approved custom category: $customCategoryName');
            final categoryId = await CategoryService.createCustomCategory(
              categoryName: customCategoryName,
              createdBy: providerData['ownerUid'] as String,
            );
            
            if (categoryId != null) {
              // Approve the category immediately
              await CategoryService.approveCustomCategory(categoryId, adminId);
              
              // Update provider with the new category ID
              transaction.update(providerRef, {
                'categoryId': categoryId,
                'isCustomCategory': false, // Now it's a regular category
                'customCategoryName': null,
              });
            }
          } else if (!existingCategory.approved) {
            // Approve existing pending category
            AppLogger.info('VerificationService: Approving existing custom category: ${existingCategory.categoryId}');
            await CategoryService.approveCustomCategory(existingCategory.categoryId, adminId);
            
            // Update provider with the category ID
            transaction.update(providerRef, {
              'categoryId': existingCategory.categoryId,
              'isCustomCategory': false, // Now it's a regular category
              'customCategoryName': null,
            });
          } else {
            // Category already exists and is approved
            AppLogger.info('VerificationService: Using existing approved category: ${existingCategory.categoryId}');
            transaction.update(providerRef, {
              'categoryId': existingCategory.categoryId,
              'isCustomCategory': false, // Now it's a regular category
              'customCategoryName': null,
            });
          }
        }
        
        // Update provider to be visible to customers
        transaction.update(providerRef, {
          'verificationStatus': 'approved',
          'visibleToCustomers': true,
          'approvedAt': FieldValue.serverTimestamp(),
          'adminNotes': adminNotes,
        });
      });

      // Update verification queue
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('providerId', isEqualTo: providerId)
          .limit(1)
          .get();

      if (queueQuery.docs.isNotEmpty) {
        await queueQuery.docs.first.reference.update({
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminId,
          'adminRemarks': adminNotes ?? '',
        });
      }

      // Get provider data for notification
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      if (providerDoc.exists) {
        final providerData = providerDoc.data()!;
        final ownerUid = providerData['ownerUid'] as String;

        // Send notification to provider
        await _sendNotification(
          receiverId: ownerUid,
          type: 'admin',
          title: 'Business Registration Approved',
          message: 'Congratulations! Your business registration has been approved. You are now visible to customers.',
        );
      }

      AppLogger.info('VerificationService: Provider approved successfully: $providerId');
      return true;
    } catch (e) {
      AppLogger.error('VerificationService: Error approving provider: $e');
      return false;
    }
  }

  /// Reject provider verification
  static Future<bool> rejectProvider({
    required String providerId,
    required String adminId,
    required String adminRemarks,
  }) async {
    try {
      // Keep provider hidden from customers
      await _firestore.collection('providers').doc(providerId).update({
        'verificationStatus': 'rejected',
        'visibleToCustomers': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'adminRemarks': adminRemarks,
      });

      // Update verification queue
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('providerId', isEqualTo: providerId)
          .limit(1)
          .get();

      if (queueQuery.docs.isNotEmpty) {
        await queueQuery.docs.first.reference.update({
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminId,
          'adminRemarks': adminRemarks,
        });
      }

      // Get provider data for notification
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      if (providerDoc.exists) {
        final providerData = providerDoc.data()!;
        final ownerUid = providerData['ownerUid'] as String;

        // Send notification to provider
        await _sendNotification(
          receiverId: ownerUid,
          type: 'admin',
          title: 'Business Registration Rejected',
          message: 'Your business registration has been rejected. Please review the feedback and resubmit.',
        );
      }

      return true;
    } catch (e) {
      AppLogger.info('Error rejecting provider: $e');
      return false;
    }
  }

  /// Get verification status for a provider
  static Future<Map<String, dynamic>?> getVerificationStatus(String ownerUid) async {
    try {
      final queueQuery = await _firestore
          .collection('verification_queue')
          .where('ownerUid', isEqualTo: ownerUid)
          .get();

      if (queueQuery.docs.isNotEmpty) {
        // Sort by submittedAt in descending order and get the most recent
        final sortedDocs = queueQuery.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['submittedAt'] as Timestamp?;
            final bTime = b.data()['submittedAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });
        
        final doc = sortedDocs.first;
        final data = doc.data();
        return {
          'id': doc.id,
          'status': data['status'],
          'submittedAt': data['submittedAt'],
          'reviewedAt': data['reviewedAt'],
          'adminRemarks': data['adminRemarks'],
          'reviewedBy': data['reviewedBy'],
        };
      }
      return null;
    } catch (e) {
      AppLogger.info('Error getting verification status: $e');
      return null;
    }
  }

  /// Get verification status stream for real-time updates
  static Stream<Map<String, dynamic>?> getVerificationStatusStream(String ownerUid) {
    AppLogger.info('VerificationService: Getting stream for ownerUid: $ownerUid');
    
        // Debug: Query all verification queue documents to see what's there
        _firestore.collection('verification_queue').get().then((snapshot) {
          AppLogger.info('VerificationService: DEBUG - All verification queue documents:');
          for (var doc in snapshot.docs) {
            final data = doc.data();
            AppLogger.info('  Document ${doc.id}: ownerUid=${data['ownerUid']}, status=${data['status']}, providerId=${data['providerId']}');
          }
        });
    
    return _firestore
        .collection('verification_queue')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) {
      AppLogger.info('VerificationService: Stream update - ${snapshot.docs.length} documents found');
      if (snapshot.docs.isNotEmpty) {
        // Sort by submittedAt in descending order and get the most recent
        final sortedDocs = snapshot.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['submittedAt'] as Timestamp?;
            final bTime = b.data()['submittedAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });
        
        final doc = sortedDocs.first;
        final data = doc.data();
        AppLogger.info('VerificationService: Found document with ownerUid: ${data['ownerUid']}, status: ${data['status']}');
        return {
          'id': doc.id,
          'status': data['status'],
          'submittedAt': data['submittedAt'],
          'reviewedAt': data['reviewedAt'],
          'adminRemarks': data['adminRemarks'],
          'reviewedBy': data['reviewedBy'],
        };
      }
      AppLogger.info('VerificationService: No documents found, returning null');
      return null;
    });
  }

  /// Check if provider is visible to customers
  static Future<bool> isVisibleToCustomers(String providerId) async {
    try {
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      if (providerDoc.exists) {
        final data = providerDoc.data()!;
        return data['visibleToCustomers'] ?? false;
      }
      return false;
    } catch (e) {
      AppLogger.info('Error checking visibility: $e');
      return false;
    }
  }

  /// Send notification to user
  static Future<void> _sendNotification({
    required String receiverId,
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      AppLogger.info('Error sending notification: $e');
    }
  }
}
