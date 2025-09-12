import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import 'package:flutter/foundation.dart';
import 'cloudinary_storage_service.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryStorageService _cloudinary = CloudinaryStorageService();
  final ImagePicker _imagePicker = ImagePicker();

  // Get user profile
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, id: uid);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error getting user profile: $e');
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
        fullName: displayName,
        profilePicture: profileImageUrl,
        role: 'customer',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userProfile.toMap());
      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error creating user profile: $e');
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    required String uid,
    String? firstName,
    File? profileImage,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (firstName != null) {
        updateData['firstName'] = firstName;
      }

      if (profileImage != null) {
        final profileImageUrl = await _uploadProfileImage(uid, profileImage);
        updateData['profileImageUrl'] = profileImageUrl;
      }

      await _firestore.collection('users').doc(uid).update(updateData);
      return true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error updating user profile: $e');
      return false;
    }
  }

  // Upload profile image to Cloudinary
  Future<String> _uploadProfileImage(String uid, File imageFile) async {
    return await _cloudinary.uploadProfileImage(imageFile);
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
      // ignore: avoid_print
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // Stream user profile updates
  Stream<UserProfile?> getUserProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!, id: uid);
      }
      return null;
    });
  }
}

