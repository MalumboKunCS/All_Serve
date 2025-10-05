import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderRegistrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a provider has completed their registration
  /// Returns true if registration is complete, false if incomplete
  static Future<bool> isRegistrationComplete(String providerId) async {
    try {
      final providerDoc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();

      if (!providerDoc.exists) {
        return false; // Provider document doesn't exist
      }

      final data = providerDoc.data()!;
      
      // Check if all required fields are filled
      final businessName = data['businessName'] as String?;
      final description = data['description'] as String?;
      final categoryId = data['categoryId'] as String?;
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      final nrcUrl = data['nrcUrl'] as String?;
      final businessLicenseUrl = data['businessLicenseUrl'] as String?;
      final certificatesUrl = data['certificatesUrl'] as String?;
      
      // Check if basic info is complete
      final basicInfoComplete = businessName != null && 
                               businessName.isNotEmpty &&
                               description != null && 
                               description.isNotEmpty &&
                               categoryId != null && 
                               categoryId.isNotEmpty;
      
      // Check if location is set (not default 0,0)
      final locationComplete = lat != null && 
                              lng != null && 
                              lat != 0.0 && 
                              lng != 0.0;
      
      // Check if documents are uploaded
      final documentsComplete = nrcUrl != null && 
                               nrcUrl.isNotEmpty &&
                               businessLicenseUrl != null && 
                               businessLicenseUrl.isNotEmpty &&
                               certificatesUrl != null && 
                               certificatesUrl.isNotEmpty;
      
      return basicInfoComplete && locationComplete && documentsComplete;
    } catch (e) {
      print('Error checking provider registration status: $e');
      return false;
    }
  }

  /// Get provider registration completion status with details
  static Future<Map<String, dynamic>> getRegistrationStatus(String providerId) async {
    try {
      final providerDoc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();

      if (!providerDoc.exists) {
        return {
          'isComplete': false,
          'isFirstTime': true,
          'missingFields': ['provider_document'],
          'progress': 0.0,
        };
      }

      final data = providerDoc.data()!;
      
      // Check individual fields
      final businessName = data['businessName'] as String?;
      final description = data['description'] as String?;
      final categoryId = data['categoryId'] as String?;
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      final nrcUrl = data['nrcUrl'] as String?;
      final businessLicenseUrl = data['businessLicenseUrl'] as String?;
      final certificatesUrl = data['certificatesUrl'] as String?;
      final profileImageUrl = data['profileImageUrl'] as String?;
      final businessLogoUrl = data['businessLogoUrl'] as String?;
      
      final missingFields = <String>[];
      double progress = 0.0;
      
      // Basic Info (40% of completion)
      if (businessName == null || businessName.isEmpty) {
        missingFields.add('business_name');
      } else {
        progress += 15.0;
      }
      
      if (description == null || description.isEmpty) {
        missingFields.add('description');
      } else {
        progress += 15.0;
      }
      
      if (categoryId == null || categoryId.isEmpty) {
        missingFields.add('category');
      } else {
        progress += 10.0;
      }
      
      // Location (20% of completion)
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
        missingFields.add('location');
      } else {
        progress += 20.0;
      }
      
      // Documents (30% of completion - 10% each)
      if (nrcUrl == null || nrcUrl.isEmpty) {
        missingFields.add('nrc_document');
      } else {
        progress += 10.0;
      }
      
      if (businessLicenseUrl == null || businessLicenseUrl.isEmpty) {
        missingFields.add('business_license');
      } else {
        progress += 10.0;
      }
      
      if (certificatesUrl == null || certificatesUrl.isEmpty) {
        missingFields.add('certificates');
      } else {
        progress += 10.0;
      }
      
      // Images (10% of completion - optional but adds to completion)
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        progress += 5.0;
      }
      
      if (businessLogoUrl != null && businessLogoUrl.isNotEmpty) {
        progress += 5.0;
      }
      
      final isComplete = progress >= 90.0; // Consider complete if 90%+ done
      final isFirstTime = missingFields.length >= 5; // Consider first time if many fields missing
      
      return {
        'isComplete': isComplete,
        'isFirstTime': isFirstTime,
        'missingFields': missingFields,
        'progress': progress,
        'providerData': data,
      };
    } catch (e) {
      print('Error getting provider registration status: $e');
      return {
        'isComplete': false,
        'isFirstTime': true,
        'missingFields': ['error'],
        'progress': 0.0,
      };
    }
  }

  /// Check if provider needs to complete registration
  static Future<bool> needsRegistrationCompletion(String providerId) async {
    final status = await getRegistrationStatus(providerId);
    return !status['isComplete'] && status['isFirstTime'];
  }

  /// Mark provider as having started registration process
  static Future<void> markRegistrationStarted(String providerId) async {
    try {
      await _firestore
          .collection('providers')
          .doc(providerId)
          .update({
        'registrationStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking registration as started: $e');
    }
  }

  /// Get registration progress percentage
  static Future<double> getRegistrationProgress(String providerId) async {
    final status = await getRegistrationStatus(providerId);
    return status['progress'] as double;
  }

  /// Get missing fields for registration
  static Future<List<String>> getMissingFields(String providerId) async {
    final status = await getRegistrationStatus(providerId);
    return List<String>.from(status['missingFields']);
  }
}
