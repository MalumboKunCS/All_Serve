import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../utils/app_logger.dart';

class CategoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a category exists by name
  static Future<bool> categoryExists(String categoryName) async {
    try {
      AppLogger.debug('CategoryService: Checking if category exists: $categoryName');
      
      final querySnapshot = await _firestore
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .get();
      
      final exists = querySnapshot.docs.isNotEmpty;
      AppLogger.debug('CategoryService: Category "$categoryName" exists: $exists');
      
      return exists;
    } catch (e) {
      AppLogger.error('CategoryService: Error checking category existence: $e');
      return false;
    }
  }

  /// Get category by name
  static Future<Category?> getCategoryByName(String categoryName) async {
    try {
      AppLogger.debug('CategoryService: Getting category by name: $categoryName');
      
      final querySnapshot = await _firestore
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final category = Category.fromFirestore(querySnapshot.docs.first);
        AppLogger.debug('CategoryService: Found category: ${category.name}');
        return category;
      }
      
      AppLogger.debug('CategoryService: Category not found: $categoryName');
      return null;
    } catch (e) {
      AppLogger.error('CategoryService: Error getting category by name: $e');
      return null;
    }
  }

  /// Create a new custom category
  static Future<String?> createCustomCategory({
    required String categoryName,
    required String createdBy,
    String? description,
  }) async {
    try {
      AppLogger.debug('CategoryService: Creating custom category: $categoryName');
      
      // Check if category already exists
      if (await categoryExists(categoryName)) {
        AppLogger.warning('CategoryService: Category already exists: $categoryName');
        return null;
      }
      
      final docRef = await _firestore.collection('categories').add({
        'name': categoryName,
        'description': description ?? 'Custom category suggested by provider',
        'isCustomCategory': true,
        'approved': false, // Pending admin approval
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'isFeatured': false,
      });
      
      AppLogger.info('CategoryService: Custom category created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('CategoryService: Error creating custom category: $e');
      return null;
    }
  }

  /// Approve a custom category
  static Future<bool> approveCustomCategory(String categoryId, String adminId) async {
    try {
      AppLogger.debug('CategoryService: Approving custom category: $categoryId');
      
      await _firestore.collection('categories').doc(categoryId).update({
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
      });
      
      AppLogger.info('CategoryService: Custom category approved: $categoryId');
      return true;
    } catch (e) {
      AppLogger.error('CategoryService: Error approving custom category: $e');
      return false;
    }
  }

  /// Get all approved categories
  static Future<List<Category>> getApprovedCategories() async {
    try {
      AppLogger.debug('CategoryService: Getting all approved categories');
      
      final querySnapshot = await _firestore
          .collection('categories')
          .where('approved', isEqualTo: true)
          .orderBy('name')
          .get();
      
      final categories = querySnapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      
      AppLogger.debug('CategoryService: Found ${categories.length} approved categories');
      return categories;
    } catch (e) {
      AppLogger.error('CategoryService: Error getting approved categories: $e');
      return [];
    }
  }

  /// Get all pending custom categories
  static Future<List<Category>> getPendingCustomCategories() async {
    try {
      AppLogger.debug('CategoryService: Getting pending custom categories');
      
      final querySnapshot = await _firestore
          .collection('categories')
          .where('isCustomCategory', isEqualTo: true)
          .where('approved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      
      final categories = querySnapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      
      AppLogger.debug('CategoryService: Found ${categories.length} pending custom categories');
      return categories;
    } catch (e) {
      AppLogger.error('CategoryService: Error getting pending custom categories: $e');
      return [];
    }
  }

  /// Get category by ID
  static Future<Category?> getCategoryById(String categoryId) async {
    try {
      AppLogger.debug('CategoryService: Getting category by ID: $categoryId');
      
      final doc = await _firestore.collection('categories').doc(categoryId).get();
      
      if (doc.exists) {
        final category = Category.fromFirestore(doc);
        AppLogger.debug('CategoryService: Found category: ${category.name}');
        return category;
      }
      
      AppLogger.debug('CategoryService: Category not found: $categoryId');
      return null;
    } catch (e) {
      AppLogger.error('CategoryService: Error getting category by ID: $e');
      return null;
    }
  }

  /// Get or create category reference for provider
  static Future<String?> getOrCreateCategoryReference({
    required String categoryName,
    required String providerUid,
  }) async {
    try {
      AppLogger.debug('CategoryService: Getting or creating category reference for: $categoryName');
      
      // First, check if category exists
      final existingCategory = await getCategoryByName(categoryName);
      
      if (existingCategory != null) {
        AppLogger.debug('CategoryService: Using existing category: ${existingCategory.categoryId}');
        return existingCategory.categoryId;
      }
      
      // Category doesn't exist, create as custom category
      AppLogger.debug('CategoryService: Creating new custom category: $categoryName');
      final categoryId = await createCustomCategory(
        categoryName: categoryName,
        createdBy: providerUid,
      );
      
      return categoryId;
    } catch (e) {
      AppLogger.error('CategoryService: Error getting or creating category reference: $e');
      return null;
    }
  }
}

