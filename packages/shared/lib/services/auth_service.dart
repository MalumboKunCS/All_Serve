import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Current user stream
  Stream<User?> get userStream => _auth.authStateChanges().asyncMap((firebaseUser) async {
    try {
      print('AuthService: Auth state changed - Firebase user: ${firebaseUser?.uid}');
      if (firebaseUser != null) {
        final user = await _getUserFromFirestore(firebaseUser.uid);
        print('AuthService: Fetched user from Firestore: ${user?.uid}, role: ${user?.role}');
        return user;
      }
      print('AuthService: No Firebase user, returning null');
      return null;
    } catch (e) {
      print('AuthService: Error in userStream: $e');
      return null;
    }
  });

  // Current user (synchronous getter for immediate access to Firebase user)
  User? get currentUser {
    final firebaseUser = _auth.currentUser;
    return firebaseUser != null ? User(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
      phone: firebaseUser.phoneNumber ?? '',
      role: 'customer', // Default role, will be updated by userStream
      deviceTokens: [],
      createdAt: DateTime.now(),
    ) : null;
  }

  // Get current user with full data from Firestore
  Future<User?> getCurrentUserWithData() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return await _getUserFromFirestore(firebaseUser.uid);
    }
    return null;
  }

  // Sign up with email and password
  Future<firebase_auth.UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      final user = User(
        uid: credential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        deviceTokens: [],
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toFirestore());

      // If user is a provider, create basic provider record with pending status
      if (role == 'provider') {
        await _createPendingProviderRecord(
          uid: credential.user!.uid,
          email: email,
          name: name,
          phone: phone,
        );
      }

      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Create pending provider record
  Future<void> _createPendingProviderRecord({
    required String uid,
    required String email,
    required String name,
    required String phone,
  }) async {
    try {
      final providerData = {
        'providerId': uid,
        'ownerUid': uid,
        'ownerName': name,
        'ownerEmail': email,
        'ownerPhone': phone,
        'businessName': '', // To be filled during registration
        'description': '',
        'categoryId': '',
        'services': [],
        'images': [],
        'lat': 0.0,
        'lng': 0.0,
        'geohash': '',
        'serviceAreaKm': 10.0,
        'documents': {},
        'verificationStatus': 'pending', // Default to pending
        'status': 'inactive', // Inactive until verified
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'isOnline': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'keywords': [],
      };

      await _firestore
          .collection('providers')
          .doc(uid)
          .set(providerData);
    } catch (e) {
      print('Error creating pending provider record: $e');
      // Don't rethrow - user creation should still succeed
    }
  }

  // Sign in with email and password
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('AuthService: Attempting sign in for email: $email');
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('AuthService: Firebase sign in successful for uid: ${credential.user?.uid}');

      // Check if 2FA is enabled
      final userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      print('AuthService: Checking user document exists: ${userDoc.exists}');

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final is2FAEnabled = userData['is2FAEnabled'] == true;
        print('AuthService: 2FA enabled: $is2FAEnabled');
        
        if (is2FAEnabled) {
          // Store temporary auth state for 2FA verification
          await _secureStorage.write(
            key: 'temp_auth_uid',
            value: credential.user!.uid,
          );
          // Sign out until 2FA is verified
          await _auth.signOut();
          print('AuthService: Signed out due to 2FA requirement');
          throw Exception('2FA_REQUIRED');
        }
      } else {
        print('AuthService: Warning - User document not found in Firestore');
      }

      print('AuthService: Sign in completed successfully');
      return credential;
    } catch (e) {
      print('AuthService: Sign in error: $e');
      rethrow;
    }
  }

  // Verify 2FA code
  Future<firebase_auth.UserCredential> verify2FACode(String code) async {
    try {
      final tempUid = await _secureStorage.read(key: 'temp_auth_uid');
      if (tempUid == null) {
        throw Exception('No temporary authentication found');
      }

      // Get user document
      final userDoc = await _firestore.collection('users').doc(tempUid).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final twoFactorSecret = userData['twoFactorSecret'];
      final backupCodes = List<String>.from(userData['backupCodes'] ?? []);

      // Verify TOTP code or backup code
      bool isValidCode = false;
      
      // Check if it's a backup code
      if (backupCodes.contains(code)) {
        isValidCode = true;
        // Remove used backup code
        backupCodes.remove(code);
        await _firestore.collection('users').doc(tempUid).update({
          'backupCodes': backupCodes,
        });
      } else {
        // Verify TOTP code
        isValidCode = await _verifyTOTPCode(code, twoFactorSecret);
      }

      if (!isValidCode) {
        throw Exception('Invalid 2FA code');
      }

      // Clear temporary storage
      await _secureStorage.delete(key: 'temp_auth_uid');

      // For 2FA verification, we need to use a different approach
      // Since we can't sign in with empty password, we'll use custom tokens
      // For now, we'll use a workaround by creating a custom credential
      
      // Store the verified 2FA state temporarily
      await _secureStorage.write(
        key: 'verified_2fa_uid',
        value: tempUid,
      );
      
      // Return a mock credential - the actual sign-in will be handled by the auth state listener
      // This is a temporary solution until proper custom tokens are implemented
      throw Exception('2FA_VERIFIED:$tempUid');
    } catch (e) {
      rethrow;
    }
  }

  // Verify TOTP code (placeholder - implement with actual TOTP library)
  Future<bool> _verifyTOTPCode(String code, String? secret) async {
    try {
      if (secret == null || code.length != 6) return false;
      
      // TODO: Implement proper TOTP verification using speakeasy
      // For development/testing, accept any 6-digit code
      return RegExp(r'^\d{6}$').hasMatch(code);
    } catch (e) {
      print('TOTP verification error: $e');
      return false;
    }
  }

  // Enable 2FA for user
  Future<void> enable2FA({
    required String uid,
    required String secret,
    required List<String> backupCodes,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'is2FAEnabled': true,
        'twoFactorSecret': secret,
        'backupCodes': backupCodes,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Disable 2FA for user
  Future<void> disable2FA(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'is2FAEnabled': false,
        'twoFactorSecret': null,
        'backupCodes': [],
      });
    } catch (e) {
      rethrow;
    }
  }

  // Generate backup codes
  List<String> generateBackupCodes() {
    final codes = <String>[];
    for (int i = 0; i < 10; i++) {
      codes.add(_generateRandomCode());
    }
    return codes;
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 8; i++) {
      code += chars[random % chars.length];
    }
    return code;
  }

  // Forgot password
  Future<void> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Re-authenticate user before changing password
        final credential = firebase_auth.EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        
        // Change password
        await user.updatePassword(newPassword);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _secureStorage.deleteAll();
    } catch (e) {
      rethrow;
    }
  }

  // Get user from Firestore
  Future<User?> _getUserFromFirestore(String uid) async {
    try {
      print('AuthService: Fetching user from Firestore for uid: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final userData = doc.data();
        print('AuthService: User document data: $userData');
        final user = User.fromFirestore(doc);
        print('AuthService: Successfully created User object for: ${user.uid}');
        return user;
      }
      print('AuthService: User document does not exist for uid: $uid');
      return null;
    } catch (e) {
      print('AuthService: Error fetching user from Firestore: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? profileImageUrl,
    Map<String, dynamic>? defaultAddress,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
      if (defaultAddress != null) updates['defaultAddress'] = defaultAddress;

      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  // Add device token for FCM
  Future<void> addDeviceToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'deviceTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Remove device token for FCM
  Future<void> removeDeviceToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'deviceTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has specific role
  Future<bool> hasRole(String uid, String role) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final userData = doc.data()!;
        return userData['role'] == role;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get user role
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final userData = doc.data()!;
        return userData['role'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if current user is admin
  bool get isAdmin {
    final user = currentUser;
    return user?.role == 'admin';
  }

  // Check if current user is provider
  bool get isProvider {
    final user = currentUser;
    return user?.role == 'provider';
  }

  // Check if current user is customer
  bool get isCustomer {
    final user = currentUser;
    return user?.role == 'customer';
  }
}


