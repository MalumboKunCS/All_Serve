import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'cloudinary_storage_service.dart';

class FileUploadService {
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
      final uploadUrl = await _cloudinary.uploadProfileImage(file);
      
      return uploadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload profile image: $e');
    }
  }

  /// Upload logo image for providers
  static Future<String?> uploadLogoImage(String providerId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 90,
      );

      if (image == null) return null;

      // Validate file
      await _validateImageFile(image);

      final file = File(image.path);
      final uploadUrl = await _cloudinary.uploadProviderLogo(file);
      
      return uploadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload logo: $e');
    }
  }

  /// Upload gallery images for providers
  static Future<List<String>> uploadGalleryImages(String providerId, {int maxImages = 5}) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (images.isEmpty) return [];

      if (images.length > maxImages) {
        throw FileUploadException('Maximum $maxImages images allowed');
      }

      final List<String> downloadUrls = [];
      
      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        
        // Validate each image
        await _validateImageFile(image);

        final file = File(image.path);
        final uploadUrl = await _cloudinary.uploadProviderGalleryImage(file);
        downloadUrls.add(uploadUrl);
      }

      return downloadUrls;
    } catch (e) {
      throw FileUploadException('Failed to upload gallery images: $e');
    }
  }

  /// Upload verification documents
  static Future<Map<String, String>> uploadVerificationDocuments(String providerId) async {
    try {
      final Map<String, String> uploadedDocs = {};

      // Define document types
      final Map<String, String> docTypes = {
        'nrc': 'National Registration Card',
        'business_license': 'Business License',
        'certificates': 'Professional Certificates',
      };

      for (final entry in docTypes.entries) {
        final docType = entry.key;
        final displayName = entry.value;

        // Ask user to select document
        final bool shouldUpload = await _confirmDocumentUpload(displayName);
        if (!shouldUpload) continue;

        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: _allowedDocumentTypes,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          
          // Validate document
          await _validateDocumentFile(file);

          if (file.bytes != null) {
            // Create temporary file from bytes
            final tempFile = File('${Directory.systemTemp.path}/${file.name}');
            await tempFile.writeAsBytes(file.bytes!);
            
            final uploadUrl = await _cloudinary.uploadDocument(tempFile);
            uploadedDocs['${docType}Url'] = uploadUrl;
            
            // Clean up temp file
            await tempFile.delete();
          } else if (file.path != null) {
            final uploadUrl = await _cloudinary.uploadDocument(File(file.path!));
            uploadedDocs['${docType}Url'] = uploadUrl;
          } else {
            throw FileUploadException('Failed to read selected file');
          }
        }
      }

      return uploadedDocs;
    } catch (e) {
      throw FileUploadException('Failed to upload documents: $e');
    }
  }

  /// Upload single document
  static Future<String?> uploadDocument(String fileName, String category) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedDocumentTypes,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate document
        await _validateDocumentFile(file);

        if (file.bytes != null) {
          // Create temporary file from bytes
          final tempFile = File('${Directory.systemTemp.path}/${file.name}');
          await tempFile.writeAsBytes(file.bytes!);
          
          final uploadUrl = await _cloudinary.uploadDocument(tempFile);
          
          // Clean up temp file
          await tempFile.delete();
          
          return uploadUrl;
        } else if (file.path != null) {
          final uploadUrl = await _cloudinary.uploadDocument(File(file.path!));
          return uploadUrl;
        } else {
          throw FileUploadException('Failed to read selected file');
        }
      }

      return null;
    } catch (e) {
      throw FileUploadException('Failed to upload document: $e');
    }
  }

  /// Upload image from camera
  static Future<String?> uploadImageFromCamera(String fileName, String category) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Validate image
      await _validateImageFile(image);

      final file = File(image.path);
      final uploadUrl = await _cloudinary.uploadProviderGalleryImage(file);
      
      return uploadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload image: $e');
    }
  }

  /// Delete file from storage
  static Future<void> deleteFile(String downloadUrl) async {
    try {
      // Extract public ID from Cloudinary URL
      final publicId = _extractPublicIdFromUrl(downloadUrl);
      if (publicId != null) {
        await _cloudinary.deleteImage(publicId);
      }
    } catch (e) {
      print('Failed to delete file: $e');
      // Don't throw error for file deletion failures
    }
  }

  /// Delete multiple files
  static Future<void> deleteFiles(List<String> downloadUrls) async {
    for (final url in downloadUrls) {
      await deleteFile(url);
    }
  }

  /// Get file metadata
  static Future<Map<String, dynamic>?> getFileMetadata(String downloadUrl) async {
    try {
      final publicId = _extractPublicIdFromUrl(downloadUrl);
      if (publicId != null) {
        return await _cloudinary.getImageInfo(publicId);
      }
      return null;
    } catch (e) {
      print('Failed to get file metadata: $e');
      return null;
    }
  }

  // Private helper methods

  /// Validate image file
  static Future<void> _validateImageFile(XFile image) async {
    // Check file size
    final fileSize = await image.length();
    if (fileSize > _maxImageSizeBytes) {
      throw FileUploadException('Image size must be less than 5MB');
    }

    // Check file type
    final extension = path.extension(image.path).toLowerCase().substring(1);
    if (!_allowedImageTypes.contains(extension)) {
      throw FileUploadException('Only JPG, PNG, and WebP images are allowed');
    }
  }

  /// Validate document file
  static Future<void> _validateDocumentFile(PlatformFile file) async {
    // Check file size
    if (file.size > _maxDocumentSizeBytes) {
      throw FileUploadException('Document size must be less than 10MB');
    }

    // Check file type
    final extension = file.extension?.toLowerCase() ?? '';
    if (!_allowedDocumentTypes.contains(extension)) {
      throw FileUploadException('Only PDF, DOC, DOCX, JPG, PNG files are allowed');
    }
  }


  /// Confirm document upload (placeholder - implement with proper UI dialog)
  static Future<bool> _confirmDocumentUpload(String documentType) async {
    // In a real app, show a dialog to confirm upload
    // For now, return true to proceed with all documents
    return true;
  }

  /// Extract public ID from Cloudinary URL
  static String? _extractPublicIdFromUrl(String url) {
    try {
      // Cloudinary URL format: https://res.cloudinary.com/cloud_name/image/upload/v1234567890/folder/public_id.ext
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Find the upload segment and get everything after it
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex != -1 && uploadIndex + 1 < pathSegments.length) {
        // Skip version if present, get the rest
        final startIndex = pathSegments[uploadIndex + 1].startsWith('v') ? uploadIndex + 2 : uploadIndex + 1;
        return pathSegments.sublist(startIndex).join('/').split('.')[0];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// File upload exception class
class FileUploadException implements Exception {
  final String message;
  
  const FileUploadException(this.message);
  
  @override
  String toString() => 'FileUploadException: $message';
}

/// Upload result class
class UploadResult {
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;
  
  const UploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });
}

/// Upload progress callback
typedef UploadProgressCallback = void Function(double progress);

/// File upload options
class FileUploadOptions {
  final int? maxWidth;
  final int? maxHeight;
  final int? imageQuality;
  final int? maxSizeBytes;
  final List<String>? allowedExtensions;
  final UploadProgressCallback? onProgress;
  
  const FileUploadOptions({
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
    this.maxSizeBytes,
    this.allowedExtensions,
    this.onProgress,
  });
}

