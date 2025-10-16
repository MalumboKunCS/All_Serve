import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String categoryId;
  final String name;
  final String? iconKey;
  final String? iconUrl;
  final String description;
  final bool isFeatured;
  final DateTime createdAt;
  final bool isCustomCategory; // NEW: Whether this is a custom category suggested by provider
  final bool approved; // NEW: Whether this custom category is approved by admin
  final String? createdBy; // NEW: UID of provider who suggested this category
  final DateTime? approvedAt; // NEW: When this category was approved by admin

  Category({
    required this.categoryId,
    required this.name,
    this.iconKey,
    this.iconUrl,
    required this.description,
    this.isFeatured = false,
    required this.createdAt,
    this.isCustomCategory = false, // Default to false for existing categories
    this.approved = true, // Default to true for existing categories
    this.createdBy,
    this.approvedAt,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Category(
      categoryId: doc.id,
      name: data['name'] ?? '',
      iconKey: data['iconKey'],
      iconUrl: data['iconUrl'],
      description: data['description'] ?? '',
      isFeatured: data['isFeatured'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isCustomCategory: data['isCustomCategory'] ?? false,
      approved: data['approved'] ?? true,
      createdBy: data['createdBy'],
      approvedAt: data['approvedAt'] != null 
          ? (data['approvedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'iconKey': iconKey,
      'iconUrl': iconUrl,
      'description': description,
      'isFeatured': isFeatured,
      'createdAt': Timestamp.fromDate(createdAt),
      'isCustomCategory': isCustomCategory,
      'approved': approved,
      'createdBy': createdBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    };
  }

  Category copyWith({
    String? name,
    String? iconKey,
    String? iconUrl,
    String? description,
    bool? isFeatured,
    bool? isCustomCategory,
    bool? approved,
    String? createdBy,
    DateTime? approvedAt,
  }) {
    return Category(
      categoryId: categoryId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt,
      isCustomCategory: isCustomCategory ?? this.isCustomCategory,
      approved: approved ?? this.approved,
      createdBy: createdBy ?? this.createdBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}



