import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/cloudinary_config.dart';

class CloudinaryStorageService {
  CloudinaryStorageService();

  // Upload image with automatic optimization
  Future<String> uploadImage({
    required File imageFile,
    required String folder,
    required String preset,
    int? width,
    int? height,
    int quality = 80,
  }) async {
    try {
      print('CloudinaryStorageService: Uploading image to folder: $folder');
      
      // Create upload request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      // Add form fields
      request.fields['upload_preset'] = preset;
      request.fields['folder'] = folder;
      request.fields['quality'] = quality.toString();
      
      if (width != null) request.fields['width'] = width.toString();
      if (height != null) request.fields['height'] = height.toString();

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final imageUrl = jsonData['secure_url'] as String;
        print('CloudinaryStorageService: Image uploaded successfully: $imageUrl');
        return imageUrl;
      } else {
        throw Exception('Upload failed: ${jsonData['error']['message']}');
      }
    } catch (e) {
      print('CloudinaryStorageService: Error uploading image: $e');
      rethrow;
    }
  }

  // Upload profile image
  Future<String> uploadProfileImage(File imageFile) async {
    return uploadImage(
      imageFile: imageFile,
      folder: 'all_serve/profile_images',
      preset: CloudinaryConfig.profileImagePreset,
      width: 400,
      height: 400,
      quality: 90,
    );
  }

  // Upload provider logo
  Future<String> uploadProviderLogo(File imageFile) async {
    return uploadImage(
      imageFile: imageFile,
      folder: 'all_serve/provider_logos',
      preset: CloudinaryConfig.providerLogoPreset,
      width: 200,
      height: 200,
      quality: 85,
    );
  }

  // Upload provider gallery image
  Future<String> uploadProviderGalleryImage(File imageFile) async {
    return uploadImage(
      imageFile: imageFile,
      folder: 'all_serve/provider_gallery',
      preset: CloudinaryConfig.providerGalleryPreset,
      width: 800,
      height: 600,
      quality: 80,
    );
  }

  // Upload document (with higher quality for readability)
  Future<String> uploadDocument(File imageFile) async {
    return uploadImage(
      imageFile: imageFile,
      folder: 'all_serve/documents',
      preset: CloudinaryConfig.documentPreset,
      width: 1200,
      height: 1600,
      quality: 75,
    );
  }

  // Upload category icon
  Future<String> uploadCategoryIcon(File imageFile) async {
    return uploadImage(
      imageFile: imageFile,
      folder: 'all_serve/category_icons',
      preset: CloudinaryConfig.categoryIconPreset,
      width: 100,
      height: 100,
      quality: 90,
    );
  }

  // Get optimized image URL with transformations
  String getOptimizedImageUrl({
    required String publicId,
    int? width,
    int? height,
    int quality = 80,
    String format = 'auto',
  }) {
    final transformations = <String>[];
    
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('q_$quality');
    transformations.add('f_$format');
    
    final transformString = transformations.join(',');
    return '${CloudinaryConfig.baseUrl}/$transformString/$publicId';
  }

  // Delete image
  Future<bool> deleteImage(String publicId) async {
    try {
      print('CloudinaryStorageService: Deleting image: $publicId');
      
      final url = 'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/destroy';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'public_id': publicId,
          'api_key': CloudinaryConfig.apiKey,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (response.statusCode == 200) {
        print('CloudinaryStorageService: Image deleted successfully');
        return true;
      } else {
        print('CloudinaryStorageService: Failed to delete image: ${response.body}');
        return false;
      }
    } catch (e) {
      print('CloudinaryStorageService: Error deleting image: $e');
      return false;
    }
  }

  // Get image info
  Future<Map<String, dynamic>?> getImageInfo(String publicId) async {
    try {
      final url = 'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/resources/image/upload/$publicId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('CloudinaryStorageService: Failed to get image info: ${response.body}');
        return null;
      }
    } catch (e) {
      print('CloudinaryStorageService: Error getting image info: $e');
      return null;
    }
  }

  // Generate image transformations for different use cases
  String getThumbnailUrl(String publicId) {
    return getOptimizedImageUrl(
      publicId: publicId,
      width: 150,
      height: 150,
      quality: 70,
    );
  }

  String getMediumUrl(String publicId) {
    return getOptimizedImageUrl(
      publicId: publicId,
      width: 400,
      height: 300,
      quality: 80,
    );
  }

  String getLargeUrl(String publicId) {
    return getOptimizedImageUrl(
      publicId: publicId,
      width: 800,
      height: 600,
      quality: 85,
    );
  }


  // Upload service image
  Future<String> uploadServiceImage(File imageFile) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'all-serve/services',
      preset: CloudinaryConfig.serviceImagePreset,
      width: 400,
      height: 300,
      quality: 85,
    );
  }
}