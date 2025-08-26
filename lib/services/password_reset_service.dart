import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PasswordResetService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Send password reset email
  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      
      // Store reset request in Firestore for tracking
      await _firestore.collection('password_reset_requests').add({
        'email': email,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'ipAddress': 'unknown', // In production, get actual IP
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Verify reset code (for SMS-based reset)
  static Future<bool> verifyResetCode(String email, String code) async {
    try {
      // Check if code exists and is valid
      QuerySnapshot query = await _firestore
          .collection('reset_codes')
          .where('email', isEqualTo: email)
          .where('code', isEqualTo: code)
          .where('expiresAt', isGreaterThan: FieldValue.serverTimestamp())
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        // Mark code as used
        await query.docs.first.reference.update({
          'used': true,
          'usedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Generate reset code for SMS
  static String generateResetCode() {
    Random random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
  
  // Store reset code in Firestore
  static Future<bool> storeResetCode(String email, String code) async {
    try {
      await _firestore.collection('reset_codes').add({
        'email': email,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(),
        'used': false,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Reset password with code
  static Future<bool> resetPasswordWithCode(String email, String code, String newPassword) async {
    try {
      // Verify the code first
      bool isValidCode = await verifyResetCode(email, code);
      if (!isValidCode) {
        return false;
      }
      
      // Get user by email
      // Note: fetchSignInMethodsForEmail is deprecated, so we'll use a different approach
      // Check if user exists in Firestore instead
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) {
        return false;
      }
      
      // For security, we'll use a different approach
      // In production, you might want to use a custom token or admin SDK
      // For now, we'll store the new password hash and require user to login again
      
      await _firestore.collection('pending_password_changes').add({
        'email': email,
        'newPasswordHash': _hashPassword(newPassword),
        'requestedAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Simple password hashing (in production, use proper hashing)
  static String _hashPassword(String password) {
    // This is a simplified hash for demo purposes
    // In production, use proper cryptographic hashing
    return password.hashCode.toString();
  }
  
  // Check if user has pending password change
  static Future<bool> hasPendingPasswordChange(String email) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('pending_password_changes')
          .where('email', isEqualTo: email)
          .where('expiresAt', isGreaterThan: FieldValue.serverTimestamp())
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // Clean up expired reset codes and requests
  static Future<void> cleanupExpiredResetData() async {
    try {
      // Clean up expired reset codes
      QuerySnapshot expiredCodes = await _firestore
          .collection('reset_codes')
          .where('expiresAt', isLessThan: FieldValue.serverTimestamp())
          .get();
      
      for (DocumentSnapshot doc in expiredCodes.docs) {
        await doc.reference.delete();
      }
      
      // Clean up expired password change requests
      QuerySnapshot expiredChanges = await _firestore
          .collection('pending_password_changes')
          .where('expiresAt', isLessThan: FieldValue.serverTimestamp())
          .get();
      
      for (DocumentSnapshot doc in expiredChanges.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Handle error silently
    }
  }
  
  // Get password reset history for a user
  static Future<List<Map<String, dynamic>>> getPasswordResetHistory(String email) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('password_reset_requests')
          .where('email', isEqualTo: email)
          .orderBy('requestedAt', descending: true)
          .limit(10)
          .get();
      
      return query.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
