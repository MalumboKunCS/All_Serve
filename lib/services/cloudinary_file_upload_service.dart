import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'cloudinary_storage_service.dart';

class CloudinaryFileUploadService {
  static final CloudinaryStorageService _cloudinary = CloudinaryStorageService();
  static final ImagePicker _imagePicker = ImagePicker();

  // File size limits
  static const int _maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _maxDocumentSizeBytes = 10 * 1024 * 1024; // 10MB

  // Allowed file types
  static const List<String> _allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> _allowedDocumentTypes = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];

  /// Upload profile image for users
  static Future<String?> uploadProfileImage(String userId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Validate file size
      final fileSize = await image.length();
      if (fileSize > _maxImageSizeBytes) {
        throw FileUploadException('Image size must be less than 5MB');
      }

      // Validate file type
      final extension = path.extension(image.path).toLowerCase().substring(1);
      if (!_allowedImageTypes.contains(extension)) {
        throw FileUploadException('Only JPG, PNG, and WebP images are allowed');
      }

      final file = File(image.path);
      final downloadUrl = await _cloudinary.uploadProfileImage(file);
      
      return downloadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload profile image: $e');
    }
  }

  /// Upload logo image for providers
  static Future<String?> uploadLogoImage(String providerId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 90,
      );

      if (image == null) return null;

      // Validate file size
      final fileSize = await image.length();
      if (fileSize > _maxImageSizeBytes) {
        throw FileUploadException('Image size must be less than 5MB');
      }

      // Validate file type
      final extension = path.extension(image.path).toLowerCase().substring(1);
      if (!_allowedImageTypes.contains(extension)) {
        throw FileUploadException('Only JPG, PNG, and WebP images are allowed');
      }

      final file = File(image.path);
      final downloadUrl = await _cloudinary.uploadProviderLogo(file);
      
      return downloadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload logo image: $e');
    }
  }

  /// Upload gallery image for providers
  static Future<String?> uploadGalleryImage(String providerId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image == null) return null;

      // Validate file size
      final fileSize = await image.length();
      if (fileSize > _maxImageSizeBytes) {
        throw FileUploadException('Image size must be less than 5MB');
      }

      // Validate file type
      final extension = path.extension(image.path).toLowerCase().substring(1);
      if (!_allowedImageTypes.contains(extension)) {
        throw FileUploadException('Only JPG, PNG, and WebP images are allowed');
      }

      final file = File(image.path);
      final downloadUrl = await _cloudinary.uploadProviderGalleryImage(file);
      
      return downloadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload gallery image: $e');
    }
  }

  /// Upload document for providers
  static Future<String?> uploadDocument(String providerId, String docType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedDocumentTypes,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = File(result.files.first.path!);
      final fileSize = await file.length();
      
      if (fileSize > _maxDocumentSizeBytes) {
        throw FileUploadException('Document size must be less than 10MB');
      }

      // Validate file type
      final extension = path.extension(file.path).toLowerCase().substring(1);
      if (!_allowedDocumentTypes.contains(extension)) {
        throw FileUploadException('Invalid document type. Allowed types: ${_allowedDocumentTypes.join(', ')}');
      }

      final downloadUrl = await _cloudinary.uploadDocument(file);
      
      return downloadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload document: $e');
    }
  }

  /// Upload category icon
  static Future<String?> uploadCategoryIcon(String categoryId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 90,
      );

      if (image == null) return null;

      // Validate file size
      final fileSize = await image.length();
      if (fileSize > _maxImageSizeBytes) {
        throw FileUploadException('Image size must be less than 5MB');
      }

      // Validate file type
      final extension = path.extension(image.path).toLowerCase().substring(1);
      if (!_allowedImageTypes.contains(extension)) {
        throw FileUploadException('Only JPG, PNG, and WebP images are allowed');
      }

      final file = File(image.path);
      final downloadUrl = await _cloudinary.uploadCategoryIcon(file);
      
      return downloadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload category icon: $e');
    }
  }

  /// Upload multiple gallery images
  static Future<List<String>> uploadMultipleGalleryImages(String providerId) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (images.isEmpty) return [];

      final List<String> uploadedUrls = [];
      
      for (final image in images) {
        // Validate file size
        final fileSize = await image.length();
        if (fileSize > _maxImageSizeBytes) {
          print('Skipping image ${image.name}: size too large');
          continue;
        }

        // Validate file type
        final extension = path.extension(image.path).toLowerCase().substring(1);
        if (!_allowedImageTypes.contains(extension)) {
          print('Skipping image ${image.name}: invalid type');
          continue;
        }

        try {
          final file = File(image.path);
          final downloadUrl = await _cloudinary.uploadProviderGalleryImage(file);
          uploadedUrls.add(downloadUrl);
        } catch (e) {
          print('Failed to upload image ${image.name}: $e');
        }
      }
      
      return uploadedUrls;
    } catch (e) {
      throw FileUploadException('Failed to upload gallery images: $e');
    }
  }

  /// Get optimized image URL
  static String getOptimizedImageUrl({
    required String imageUrl,
    int? width,
    int? height,
    int quality = 80,
  }) {
    // Extract public ID from Cloudinary URL
    final uri = Uri.parse(imageUrl);
    final pathSegments = uri.pathSegments;
    
    if (pathSegments.length >= 3 && pathSegments[0] == 'image' && pathSegments[1] == 'upload') {
      final publicId = pathSegments.sublist(2).join('/');
      return _cloudinary.getOptimizedImageUrl(
        publicId: publicId,
        width: width,
        height: height,
        quality: quality,
      );
    }
    
    return imageUrl; // Return original URL if not a Cloudinary URL
  }

  /// Get thumbnail URL
  static String getThumbnailUrl(String imageUrl) {
    return getOptimizedImageUrl(
      imageUrl: imageUrl,
      width: 150,
      height: 150,
      quality: 70,
    );
  }

  /// Get medium size URL
  static String getMediumUrl(String imageUrl) {
    return getOptimizedImageUrl(
      imageUrl: imageUrl,
      width: 400,
      height: 300,
      quality: 80,
    );
  }

  /// Get large size URL
  static String getLargeUrl(String imageUrl) {
    return getOptimizedImageUrl(
      imageUrl: imageUrl,
      width: 800,
      height: 600,
      quality: 85,
    );
  }

  /// Delete image
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract public ID from Cloudinary URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 3 && pathSegments[0] == 'image' && pathSegments[1] == 'upload') {
        final publicId = pathSegments.sublist(2).join('/');
        return await _cloudinary.deleteImage(publicId);
      }
      
      return false; // Not a Cloudinary URL
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }
}

/// Custom exception for file upload errors
class FileUploadException implements Exception {
  final String message;
  FileUploadException(this.message);
  
  @override
  String toString() => 'FileUploadException: $message';
}
