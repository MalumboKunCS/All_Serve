import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceCategory {
  final String id;
  final String name;
  final String icon;
  final String description;
  final List<String> subcategories;
  final bool isActive;
  final int sortOrder;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.subcategories = const [],
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory ServiceCategory.fromMap(Map<String, dynamic> map) {
    return ServiceCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'build',
      description: map['description'] ?? '',
      subcategories: List<String>.from(map['subcategories'] ?? []),
      isActive: map['isActive'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
      'subcategories': subcategories,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }

  factory ServiceCategory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ServiceCategory.fromMap({
      'id': doc.id,
      ...data,
    });
  }
}

class ServiceCategories {
  static final List<ServiceCategory> defaultCategories = [
    ServiceCategory(
      id: 'beauty',
      name: 'Beauty & Wellness',
      icon: 'face',
      description: 'Hair, makeup, spa, and personal care services',
      subcategories: ['Hair Styling', 'Makeup', 'Spa & Massage', 'Nail Care', 'Skincare'],
      sortOrder: 1,
    ),
    ServiceCategory(
      id: 'home_services',
      name: 'Home Services',
      icon: 'home',
      description: 'Cleaning, maintenance, and home improvement',
      subcategories: ['House Cleaning', 'Plumbing', 'Electrical', 'Carpentry', 'Painting'],
      sortOrder: 2,
    ),
    ServiceCategory(
      id: 'automotive',
      name: 'Automotive',
      icon: 'directions_car',
      description: 'Car repair, maintenance, and detailing',
      subcategories: ['Car Repair', 'Car Wash', 'Oil Change', 'Tire Service', 'Detailing'],
      sortOrder: 3,
    ),
    ServiceCategory(
      id: 'technology',
      name: 'Technology',
      icon: 'computer',
      description: 'IT support, device repair, and tech services',
      subcategories: ['Computer Repair', 'Phone Repair', 'IT Support', 'Software', 'Networking'],
      sortOrder: 4,
    ),
    ServiceCategory(
      id: 'education',
      name: 'Education & Training',
      icon: 'school',
      description: 'Tutoring, lessons, and educational services',
      subcategories: ['Tutoring', 'Music Lessons', 'Language Learning', 'Test Prep', 'Skills Training'],
      sortOrder: 5,
    ),
    ServiceCategory(
      id: 'health_fitness',
      name: 'Health & Fitness',
      icon: 'fitness_center',
      description: 'Personal training, health services, and wellness',
      subcategories: ['Personal Training', 'Yoga', 'Physical Therapy', 'Nutrition', 'Mental Health'],
      sortOrder: 6,
    ),
    ServiceCategory(
      id: 'events',
      name: 'Events & Entertainment',
      icon: 'event',
      description: 'Party planning, photography, and entertainment',
      subcategories: ['Photography', 'Event Planning', 'Catering', 'DJ Services', 'Decorations'],
      sortOrder: 7,
    ),
    ServiceCategory(
      id: 'business',
      name: 'Business Services',
      icon: 'business',
      description: 'Professional services and business support',
      subcategories: ['Accounting', 'Legal', 'Marketing', 'Consulting', 'Administrative'],
      sortOrder: 8,
    ),
    ServiceCategory(
      id: 'transportation',
      name: 'Transportation',
      icon: 'local_taxi',
      description: 'Delivery, moving, and transportation services',
      subcategories: ['Delivery', 'Moving', 'Ride Sharing', 'Courier', 'Logistics'],
      sortOrder: 9,
    ),
    ServiceCategory(
      id: 'other',
      name: 'Other Services',
      icon: 'more_horiz',
      description: 'Miscellaneous services not in other categories',
      subcategories: ['Pet Care', 'Gardening', 'Security', 'Custom Services'],
      sortOrder: 10,
    ),
  ];

  static List<ServiceCategory> getCategories() {
    return defaultCategories.where((cat) => cat.isActive).toList();
  }

  static ServiceCategory? getCategoryById(String id) {
    try {
      return defaultCategories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<String> getSubcategories(String categoryId) {
    final category = getCategoryById(categoryId);
    return category?.subcategories ?? [];
  }
}
