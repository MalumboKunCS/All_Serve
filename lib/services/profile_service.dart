import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:all_server/models/user_profile.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Get user profile
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Create user profile
  Future<bool> createUserProfile({
    required String uid,
    required String email,
    String? displayName,
    File? profileImage,
  }) async {
    try {
      String? profileImageUrl;
      
      if (profileImage != null) {
        profileImageUrl = await _uploadProfileImage(uid, profileImage);
      }

      final userProfile = UserProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        profileImageUrl: profileImageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userProfile.toMap());
      return true;
    } catch (e) {
      print('Error creating user profile: $e');
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    required String uid,
    String? displayName,
    File? profileImage,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (displayName != null) {
        updateData['displayName'] = displayName;
      }

      if (profileImage != null) {
        final profileImageUrl = await _uploadProfileImage(uid, profileImage);
        updateData['profileImageUrl'] = profileImageUrl;
      }

      await _firestore.collection('users').doc(uid).update(updateData);
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // Upload profile image to Firebase Storage
  Future<String> _uploadProfileImage(String uid, File imageFile) async {
    final ref = _storage.ref().child('profile_images/$uid');
    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Pick image from gallery or camera
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Stream user profile updates
  Stream<UserProfile?> getUserProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, uid);
      }
      return null;
    });
  }
}

