import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../utils/app_logger.dart';

class AdminManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Check if current user is a super admin
  Future<bool> isSuperAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return data['isSuperAdmin'] == true;
    } catch (e) {
      AppLogger.info('Error checking super admin status: $e');
      return false;
    }
  }

  // Check if current user is any type of admin
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (e) {
      AppLogger.info('Error checking admin status: $e');
      return false;
    }
  }

  // Create a new admin user
  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required String name,
    required String phone,
    required bool isSuperAdmin,
    required String createdBy,
  }) async {
    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      // Create user document in users collection
      final user = User(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        role: 'admin',
        deviceTokens: [],
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(user.toFirestore());

      // Create admin document in admins collection
      await _firestore.collection('admins').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'isSuperAdmin': isSuperAdmin,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'permissions': isSuperAdmin ? [
          'manage_admins',
          'manage_users',
          'manage_providers',
          'manage_reviews',
          'manage_announcements',
          'view_analytics',
          'manage_settings'
        ] : [
          'manage_users',
          'manage_providers',
          'manage_reviews',
          'manage_announcements',
          'view_analytics'
        ],
      });

      // Log admin creation
      await _firestore.collection('adminAuditLogs').add({
        'actorUid': createdBy,
        'action': 'create_admin',
        'targetUid': uid,
        'targetEmail': email,
        'isSuperAdmin': isSuperAdmin,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'Admin user created: $name ($email)',
      });

      return {
        'success': true,
        'uid': uid,
        'message': 'Admin created successfully',
      };
    } catch (e) {
      AppLogger.info('Error creating admin: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get all admins
  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    try {
      final querySnapshot = await _firestore
          .collection('admins')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      AppLogger.info('Error getting admins: $e');
      return [];
    }
  }

  // Update admin permissions
  Future<Map<String, dynamic>> updateAdminPermissions({
    required String adminUid,
    required List<String> permissions,
    required String updatedBy,
  }) async {
    try {
      await _firestore.collection('admins').doc(adminUid).update({
        'permissions': permissions,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      // Log permission update
      await _firestore.collection('adminAuditLogs').add({
        'actorUid': updatedBy,
        'action': 'update_admin_permissions',
        'targetUid': adminUid,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'Updated permissions: ${permissions.join(', ')}',
      });

      return {
        'success': true,
        'message': 'Admin permissions updated successfully',
      };
    } catch (e) {
      AppLogger.info('Error updating admin permissions: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Deactivate admin
  Future<Map<String, dynamic>> deactivateAdmin({
    required String adminUid,
    required String deactivatedBy,
    String? reason,
  }) async {
    try {
      await _firestore.collection('admins').doc(adminUid).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivatedBy': deactivatedBy,
        'deactivationReason': reason ?? 'No reason provided',
      });

      // Log admin deactivation
      await _firestore.collection('adminAuditLogs').add({
        'actorUid': deactivatedBy,
        'action': 'deactivate_admin',
        'targetUid': adminUid,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'Admin deactivated. Reason: ${reason ?? 'No reason provided'}',
      });

      return {
        'success': true,
        'message': 'Admin deactivated successfully',
      };
    } catch (e) {
      AppLogger.info('Error deactivating admin: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Reactivate admin
  Future<Map<String, dynamic>> reactivateAdmin({
    required String adminUid,
    required String reactivatedBy,
  }) async {
    try {
      await _firestore.collection('admins').doc(adminUid).update({
        'isActive': true,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': reactivatedBy,
        'deactivationReason': null,
      });

      // Log admin reactivation
      await _firestore.collection('adminAuditLogs').add({
        'actorUid': reactivatedBy,
        'action': 'reactivate_admin',
        'targetUid': adminUid,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'Admin reactivated',
      });

      return {
        'success': true,
        'message': 'Admin reactivated successfully',
      };
    } catch (e) {
      AppLogger.info('Error reactivating admin: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get admin audit logs
  Future<List<Map<String, dynamic>>> getAdminAuditLogs({
    int limit = 50,
    String? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('adminAuditLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        final startAfterDoc = await _firestore
            .collection('adminAuditLogs')
            .doc(startAfter)
            .get();
        query = query.startAfterDocument(startAfterDoc);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      AppLogger.info('Error getting admin audit logs: $e');
      return [];
    }
  }
}
