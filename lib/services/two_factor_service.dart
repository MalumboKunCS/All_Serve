import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TwoFactorService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate a random 6-digit OTP
  static String generateOTP() {
    Random random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
  
  // Generate a secret key for TOTP
  static String generateSecretKey() {
    Random random = Random();
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Hash the OTP for secure storage
  static String hashOTP(String otp) {
    var bytes = utf8.encode(otp);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Store OTP in secure storage
  static Future<void> storeOTP(String userId, String hashedOTP) async {
    await _storage.write(key: 'otp_$userId', value: hashedOTP);
    await _storage.write(key: 'otp_timestamp_$userId', value: DateTime.now().millisecondsSinceEpoch.toString());
  }
  
  // Verify OTP
  static Future<bool> verifyOTP(String userId, String otp) async {
    try {
      String? storedHash = await _storage.read(key: 'otp_$userId');
      String? timestampStr = await _storage.read(key: 'otp_timestamp_$userId');
      
      if (storedHash == null || timestampStr == null) {
        return false;
      }
      
      // Check if OTP is expired (5 minutes)
      int timestamp = int.parse(timestampStr);
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      if (currentTime - timestamp > 5 * 60 * 1000) {
        await _storage.delete(key: 'otp_$userId');
        await _storage.delete(key: 'otp_timestamp_$userId');
        return false;
      }
      
      String inputHash = hashOTP(otp);
      return storedHash == inputHash;
    } catch (e) {
      return false;
    }
  }
  
  // Send OTP to user (in real app, this would send SMS/email)
  static Future<bool> sendOTP(String userId, String email) async {
    try {
      String otp = generateOTP();
      String hashedOTP = hashOTP(otp);
      
      // Store OTP securely
      await storeOTP(userId, hashedOTP);
      
      // Store OTP in Firestore for verification (in production, use SMS/email service)
      await _firestore.collection('otp_codes').doc(userId).set({
        'otp': hashedOTP,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(),
      });
      
      // In production, integrate with SMS/email service here
      // For now, we'll just return success
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Enable 2FA for a user
  static Future<bool> enable2FA(String userId, String secretKey) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'twoFactorEnabled': true,
        'twoFactorSecret': secretKey,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Disable 2FA for a user
  static Future<bool> disable2FA(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'twoFactorEnabled': false,
        'twoFactorSecret': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Check if user has 2FA enabled
  static Future<bool> is2FAEnabled(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['twoFactorEnabled'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Verify TOTP code
  static bool verifyTOTP(String secretKey, String totp) {
    // This is a simplified TOTP verification
    // In production, use proper TOTP library
    try {
      // For now, we'll just check if it's a 6-digit number
      if (totp.length == 6 && int.tryParse(totp) != null) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Clean up expired OTPs
  static Future<void> cleanupExpiredOTPs() async {
    try {
      QuerySnapshot expiredOTPs = await _firestore
          .collection('otp_codes')
          .where('expiresAt', isLessThan: FieldValue.serverTimestamp())
          .get();
      
      for (DocumentSnapshot doc in expiredOTPs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Handle error silently
    }
  }
}
