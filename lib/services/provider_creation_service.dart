import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/provider.dart' as app_provider;
import 'category_service.dart';
import '../utils/app_logger.dart';

class ProviderCreationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a basic provider document if it doesn't exist
  static Future<app_provider.Provider?> createProviderIfNotExists() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('ProviderCreationService: No authenticated user');
        return null;
      }

      AppLogger.debug('ProviderCreationService: Checking if provider document exists for user: ${currentUser.uid}');

      // Check if provider document already exists
      final existingQuery = await _firestore
          .collection('providers')
          .where('ownerUid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        AppLogger.debug('ProviderCreationService: Provider document already exists');
        final doc = existingQuery.docs.first;
        return app_provider.Provider.fromFirestore(doc);
      }

      AppLogger.info('ProviderCreationService: Creating new provider document');
      
      // Create a basic provider document
      final providerData = {
        'ownerUid': currentUser.uid,
        'businessName': currentUser.displayName ?? 'My Business',
        'description': '',
        'categoryId': 'general',
        'services': [], // Initialize empty services array
        'logoUrl': null,
        'images': [],
        'websiteUrl': null,
        'lat': 0.0,
        'lng': 0.0,
        'geohash': '',
        'serviceAreaKm': 10.0,
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'verified': false,
        'verificationStatus': 'pending',
        'documents': {},
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'keywords': [],
        'galleryImages': [],
        'adminNotes': null,
        'visibleToCustomers': false,
        'isOnline': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };

      // Use the user's UID as the document ID
      await _firestore
          .collection('providers')
          .doc(currentUser.uid)
          .set(providerData);

      AppLogger.info('ProviderCreationService: Provider document created with ID: ${currentUser.uid}');

      // Return the created provider
      final createdDoc = await _firestore
          .collection('providers')
          .doc(currentUser.uid)
          .get();

      if (createdDoc.exists) {
        return app_provider.Provider.fromFirestore(createdDoc);
      }

      return null;
    } catch (e) {
      AppLogger.error('ProviderCreationService: Error creating provider document: $e');
      return null;
    }
  }

  /// Check if user has a provider document
  static Future<bool> hasProviderDocument() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final query = await _firestore
          .collection('providers')
          .where('ownerUid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      AppLogger.error('ProviderCreationService: Error checking provider document: $e');
      return false;
    }
  }

  /// Create a provider with smart category handling
  static Future<bool> createProviderWithCategory({
    required String ownerUid,
    required String businessName,
    required String description,
    required String categoryName, // This can be either existing category name or custom category name
    String? websiteUrl,
    double lat = 0.0,
    double lng = 0.0,
    double serviceAreaKm = 10.0,
  }) async {
    try {
      AppLogger.info('ProviderCreationService: Creating provider with category: $categoryName');
      
      // Check if category exists
      final categoryExists = await CategoryService.categoryExists(categoryName);
      
      String categoryId;
      bool isCustomCategory;
      String? customCategoryName;
      
      if (categoryExists) {
        // Category exists, get its ID
        final category = await CategoryService.getCategoryByName(categoryName);
        if (category != null) {
          categoryId = category.categoryId;
          isCustomCategory = false;
          customCategoryName = null;
          AppLogger.info('ProviderCreationService: Using existing category: $categoryId');
        } else {
          throw Exception('Category exists but could not be retrieved');
        }
      } else {
        // Category doesn't exist, create as custom category
        categoryId = 'pending'; // Temporary ID until approved
        isCustomCategory = true;
        customCategoryName = categoryName;
        AppLogger.info('ProviderCreationService: Creating custom category: $categoryName');
      }
      
      // Create provider document
      final providerData = {
        'ownerUid': ownerUid,
        'businessName': businessName,
        'description': description,
        'categoryId': categoryId,
        'customCategoryName': customCategoryName,
        'isCustomCategory': isCustomCategory,
        'services': [],
        'logoUrl': null,
        'images': [],
        'websiteUrl': websiteUrl,
        'lat': lat,
        'lng': lng,
        'geohash': '',
        'serviceAreaKm': serviceAreaKm,
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'verified': false,
        'verificationStatus': 'pending',
        'documents': {},
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'keywords': [],
        'galleryImages': [],
        'adminNotes': null,
        'visibleToCustomers': false,
        'isOnline': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };
      
      // Use the user's UID as the document ID
      await _firestore
          .collection('providers')
          .doc(ownerUid)
          .set(providerData);
      
      AppLogger.info('ProviderCreationService: Provider created with custom category handling');
      return true;
    } catch (e) {
      AppLogger.error('ProviderCreationService: Error creating provider with category: $e');
      return false;
    }
  }
}
