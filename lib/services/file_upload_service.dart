import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class FileUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _imagePicker = ImagePicker();

  // Upload types
  static const String _documentsPath = 'documents';
  static const String _imagesPath = 'images';
  static const String _profileImagesPath = 'profile_images';
  static const String _logoImagesPath = 'logo_images';
  static const String _galleryImagesPath = 'gallery_images';

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

      final fileName = 'profile_$userId.${extension}';
      final filePath = '$_profileImagesPath/$fileName';

      final file = File(image.path);
      final uploadTask = _storage.ref().child(filePath).putFile(file);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
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
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 90,
      );

      if (image == null) return null;

      // Validate file
      await _validateImageFile(image);

      final extension = path.extension(image.path).toLowerCase().substring(1);
      final fileName = 'logo_$providerId.${extension}';
      final filePath = '$_logoImagesPath/$fileName';

      final downloadUrl = await _uploadFile(image.path, filePath);
      return downloadUrl;
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

        final extension = path.extension(image.path).toLowerCase().substring(1);
        final fileName = 'gallery_${providerId}_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
        final filePath = '$_galleryImagesPath/$fileName';

        final downloadUrl = await _uploadFile(image.path, filePath);
        downloadUrls.add(downloadUrl);
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
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          
          // Validate document
          await _validateDocumentFile(file);

          final fileName = '${docType}_$providerId.${file.extension}';
          final filePath = '$_documentsPath/$fileName';

          final downloadUrl = await _uploadFileBytes(file.bytes!, filePath);
          uploadedDocs['${docType}Url'] = downloadUrl;
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
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate document
        await _validateDocumentFile(file);

        final sanitizedFileName = _sanitizeFileName(fileName);
        final filePath = '$_documentsPath/$category/${sanitizedFileName}.${file.extension}';

        final downloadUrl = await _uploadFileBytes(file.bytes!, filePath);
        return downloadUrl;
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

      final extension = path.extension(image.path).toLowerCase().substring(1);
      final sanitizedFileName = _sanitizeFileName(fileName);
      final filePath = '$_imagesPath/$category/${sanitizedFileName}.$extension';

      final downloadUrl = await _uploadFile(image.path, filePath);
      return downloadUrl;
    } catch (e) {
      throw FileUploadException('Failed to upload image: $e');
    }
  }

  /// Delete file from storage
  static Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
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
  static Future<FullMetadata?> getFileMetadata(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      return await ref.getMetadata();
    } catch (e) {
      print('Failed to get file metadata: $e');
      return null;
    }
  }

  // Private helper methods

  /// Upload file from path
  static Future<String> _uploadFile(String filePath, String storagePath) async {
    final file = File(filePath);
    final uploadTask = _storage.ref().child(storagePath).putFile(file);
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload file from bytes
  static Future<String> _uploadFileBytes(Uint8List bytes, String storagePath) async {
    final uploadTask = _storage.ref().child(storagePath).putData(bytes);
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

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

  /// Sanitize file name
  static String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// Confirm document upload (placeholder - implement with proper UI dialog)
  static Future<bool> _confirmDocumentUpload(String documentType) async {
    // In a real app, show a dialog to confirm upload
    // For now, return true to proceed with all documents
    return true;
  }

  /// Create upload progress stream
  static Stream<double> uploadWithProgress(String filePath, String storagePath) {
    final file = File(filePath);
    final uploadTask = _storage.ref().child(storagePath).putFile(file);
    
    return uploadTask.snapshotEvents.map((snapshot) {
      return snapshot.bytesTransferred / snapshot.totalBytes;
    });
  }

  /// Get storage reference
  static Reference getStorageRef(String path) {
    return _storage.ref().child(path);
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

