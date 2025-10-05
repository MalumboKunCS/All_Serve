import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

class CategorySetupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize default categories in Firestore if they don't exist
  static Future<void> initializeDefaultCategories() async {
    try {
      // Check if categories already exist
      final categoriesSnapshot = await _firestore.collection('categories').limit(1).get();
      
      if (categoriesSnapshot.docs.isNotEmpty) {
        print('Categories already exist in database');
        return;
      }

      print('No categories found, initializing default categories...');
      
      final defaultCategories = _getDefaultCategories();
      
      // Add categories to Firestore
      for (final category in defaultCategories) {
        await _firestore
            .collection('categories')
            .doc(category.categoryId)
            .set(category.toFirestore());
      }
      
      print('Successfully initialized ${defaultCategories.length} default categories');
    } catch (e) {
      print('Error initializing default categories: $e');
    }
  }

  /// Get default categories
  static List<Category> _getDefaultCategories() {
    return [
      Category(
        categoryId: 'plumbing',
        name: 'Plumbing',
        description: 'Plumbing services and repairs including pipe installation, leak repairs, and fixture installation',
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'electrical',
        name: 'Electrical',
        description: 'Electrical services including wiring, outlet installation, and electrical repairs',
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'carpentry',
        name: 'Carpentry',
        description: 'Carpentry and woodworking services including furniture making and repairs',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'cleaning',
        name: 'Cleaning Services',
        description: 'House and office cleaning services including deep cleaning and regular maintenance',
        isFeatured: true,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'painting',
        name: 'Painting',
        description: 'Interior and exterior painting services for homes and businesses',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'hvac',
        name: 'HVAC',
        description: 'Heating, ventilation, and air conditioning installation and repair services',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'gardening',
        name: 'Gardening',
        description: 'Landscaping and garden maintenance services including lawn care and plant installation',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'auto_repair',
        name: 'Auto Repair',
        description: 'Automotive repair and maintenance services for all vehicle types',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'appliance_repair',
        name: 'Appliance Repair',
        description: 'Home appliance repair and maintenance services',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'roofing',
        name: 'Roofing',
        description: 'Roof installation, repair, and maintenance services',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'flooring',
        name: 'Flooring',
        description: 'Floor installation and repair services including tile, wood, and carpet',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
      Category(
        categoryId: 'security',
        name: 'Security Services',
        description: 'Home and business security system installation and monitoring',
        isFeatured: false,
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Check if categories exist in database
  static Future<bool> hasCategories() async {
    try {
      final snapshot = await _firestore.collection('categories').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking categories: $e');
      return false;
    }
  }

  /// Get category count
  static Future<int> getCategoryCount() async {
    try {
      final snapshot = await _firestore.collection('categories').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting category count: $e');
      return 0;
    }
  }
}



