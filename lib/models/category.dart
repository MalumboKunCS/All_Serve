import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String categoryId;
  final String name;
  final String? iconKey;
  final String? iconUrl;
  final String description;
  final bool isFeatured;
  final DateTime createdAt;

  Category({
    required this.categoryId,
    required this.name,
    this.iconKey,
    this.iconUrl,
    required this.description,
    this.isFeatured = false,
    required this.createdAt,
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
    };
  }

  Category copyWith({
    String? name,
    String? iconKey,
    String? iconUrl,
    String? description,
    bool? isFeatured,
  }) {
    return Category(
      categoryId: categoryId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt,
    );
  }
}



