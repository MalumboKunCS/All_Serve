import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String serviceId;
  final String title;
  final String category;
  final String type; // 'priced', 'negotiable', 'free'
  final String serviceType; // NEW: 'bookable' or 'contact' - determines if service can be booked or requires contact
  final String? description;
  final double? priceFrom; // Nullable for non-priced services
  final double? priceTo; // Nullable for non-priced services
  final String? duration; // Changed from int durationMin to String duration for flexibility
  final String? imageUrl; // Deprecated - use imageUrls instead
  final List<String> imageUrls; // New: supports multiple images
  final List<String> availability; // e.g., ['monday', 'tuesday', 'wednesday']
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? contactInfo; // NEW: Contact information for contact-type services

  Service({
    required this.serviceId,
    required this.title,
    required this.category,
    required this.type,
    this.serviceType = 'bookable', // Default to bookable for backward compatibility
    this.description,
    this.priceFrom,
    this.priceTo,
    this.duration,
    this.imageUrl,
    this.imageUrls = const [],
    this.availability = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.contactInfo, // Nullable for contact services
  });

  factory Service.fromMap(Map<String, dynamic> map) {
    // Handle both old (imageUrl) and new (imageUrls) formats for backward compatibility
    List<String> imageUrls = [];
    if (map['imageUrls'] != null) {
      imageUrls = List<String>.from(map['imageUrls']);
    } else if (map['imageUrl'] != null && map['imageUrl'].toString().isNotEmpty) {
      // Migrate old single imageUrl to new imageUrls list
      imageUrls = [map['imageUrl']];
    }
    
    // Handle backward compatibility for duration field
    String? duration;
    if (map['duration'] != null) {
      duration = map['duration'] as String;
    } else if (map['durationMin'] != null) {
      // Convert old durationMin to duration string
      duration = '${map['durationMin']} minutes';
    }
    
    return Service(
      serviceId: map['serviceId'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'general',
      type: map['type'] ?? 'priced', // Default to 'priced' for backward compatibility
      serviceType: map['serviceType'] ?? 'bookable', // Default to 'bookable' for backward compatibility
      description: map['description'],
      priceFrom: map['priceFrom'] != null ? (map['priceFrom'] as num).toDouble() : null,
      priceTo: map['priceTo'] != null ? (map['priceTo'] as num).toDouble() : null,
      duration: duration,
      imageUrl: map['imageUrl'], // Keep for backward compatibility
      imageUrls: imageUrls, // New field
      availability: List<String>.from(map['availability'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      contactInfo: map['contactInfo'] as Map<String, dynamic>?, // NEW: Contact information
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'title': title,
      'category': category,
      'type': type,
      'serviceType': serviceType, // NEW: Service type for booking/contact
      'description': description,
      'priceFrom': priceFrom,
      'priceTo': priceTo,
      'duration': duration,
      'imageUrls': imageUrls, // New field - store multiple image URLs
      'imageUrl': imageUrl,
      'availability': availability,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (contactInfo != null) 'contactInfo': contactInfo, // NEW: Conditional contact info
    };
  }

  Service copyWith({
    String? title,
    String? category,
    String? type,
    String? serviceType,
    String? description,
    double? priceFrom,
    double? priceTo,
    String? duration,
    String? imageUrl,
    List<String>? availability,
    bool? isActive,
    DateTime? updatedAt,
    Map<String, dynamic>? contactInfo,
  }) {
    return Service(
      serviceId: serviceId,
      title: title ?? this.title,
      category: category ?? this.category,
      type: type ?? this.type,
      serviceType: serviceType ?? this.serviceType,
      description: description ?? this.description,
      priceFrom: priceFrom ?? this.priceFrom,
      priceTo: priceTo ?? this.priceTo,
      duration: duration ?? this.duration,
      imageUrl: imageUrl ?? this.imageUrl,
      availability: availability ?? this.availability,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }
}

class Provider {
  final String providerId;
  final String ownerUid;
  final String businessName;
  final String description;
  final String categoryId;
  final String? customCategoryName; // NEW: Name of custom category if isCustomCategory is true
  final bool isCustomCategory; // NEW: Whether this provider uses a custom category
  final List<Service> services;
  final String? logoUrl;
  final List<String> images;
  final String? websiteUrl;
  final double lat;
  final double lng;
  final String geohash;
  final double serviceAreaKm;
  final double ratingAvg;
  final int ratingCount;
  final bool verified;
  final String verificationStatus; // "pending" | "approved" | "rejected"
  final Map<String, String> documents; // {nrcUrl, businessLicenseUrl, otherDocs...}
  final String status; // "active" | "suspended" | "inactive"
  final DateTime createdAt;
  final List<String> keywords; // for search functionality
  final List<String> galleryImages; // Gallery images URLs
  final String? adminNotes; // Admin notes for verification

  Provider({
    required this.providerId,
    required this.ownerUid,
    required this.businessName,
    required this.description,
    required this.categoryId,
    this.customCategoryName,
    this.isCustomCategory = false, // Default to false for existing providers
    required this.services,
    this.logoUrl,
    required this.images,
    this.websiteUrl,
    required this.lat,
    required this.lng,
    required this.geohash,
    required this.serviceAreaKm,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.verified = false,
    this.verificationStatus = 'pending',
    required this.documents,
    this.status = 'active',
    required this.createdAt,
    required this.keywords,
    this.galleryImages = const [],
    this.adminNotes,
  });

  factory Provider.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Provider(
      providerId: doc.id,
      ownerUid: data['ownerUid'] ?? '',
      businessName: data['businessName'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      customCategoryName: data['customCategoryName'],
      isCustomCategory: data['isCustomCategory'] ?? false,
      services: (data['services'] as List<dynamic>?)
              ?.map((e) => Service.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      logoUrl: data['logoUrl'],
      images: List<String>.from(data['images'] ?? []),
      websiteUrl: data['websiteUrl'],
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      geohash: data['geohash'] ?? '',
      serviceAreaKm: (data['serviceAreaKm'] ?? 0.0).toDouble(),
      ratingAvg: (data['ratingAvg'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      verified: data['verified'] ?? false,
      verificationStatus: data['verificationStatus'] ?? 'pending',
      documents: Map<String, String>.from(data['documents'] ?? {}),
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      keywords: List<String>.from(data['keywords'] ?? []),
      galleryImages: List<String>.from(data['galleryImages'] ?? []),
      adminNotes: data['adminNotes'],
    );
  }

  factory Provider.fromMap(Map<String, dynamic> data, {String? id}) {
    return Provider(
      providerId: id ?? data['providerId'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      businessName: data['businessName'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      customCategoryName: data['customCategoryName'],
      isCustomCategory: data['isCustomCategory'] ?? false,
      services: (data['services'] as List<dynamic>?)
              ?.map((e) => Service.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      logoUrl: data['logoUrl'],
      images: List<String>.from(data['images'] ?? []),
      websiteUrl: data['websiteUrl'],
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      geohash: data['geohash'] ?? '',
      serviceAreaKm: (data['serviceAreaKm'] ?? 0.0).toDouble(),
      ratingAvg: (data['ratingAvg'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      verified: data['verified'] ?? false,
      verificationStatus: data['verificationStatus'] ?? 'pending',
      documents: Map<String, String>.from(data['documents'] ?? {}),
      status: data['status'] ?? 'active',
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      keywords: List<String>.from(data['keywords'] ?? []),
      galleryImages: List<String>.from(data['galleryImages'] ?? []),
      adminNotes: data['adminNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'businessName': businessName,
      'description': description,
      'categoryId': categoryId,
      'customCategoryName': customCategoryName,
      'isCustomCategory': isCustomCategory,
      'services': services.map((e) => e.toMap()).toList(),
      'logoUrl': logoUrl,
      'images': images,
      'websiteUrl': websiteUrl,
      'lat': lat,
      'lng': lng,
      'geohash': geohash,
      'serviceAreaKm': serviceAreaKm,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'verified': verified,
      'verificationStatus': verificationStatus,
      'documents': documents,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'keywords': keywords,
      'galleryImages': galleryImages,
      'adminNotes': adminNotes,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'ownerUid': ownerUid,
      'businessName': businessName,
      'description': description,
      'categoryId': categoryId,
      'services': services.map((e) => e.toMap()).toList(),
      'logoUrl': logoUrl,
      'images': images,
      'websiteUrl': websiteUrl,
      'lat': lat,
      'lng': lng,
      'geohash': geohash,
      'serviceAreaKm': serviceAreaKm,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'verified': verified,
      'verificationStatus': verificationStatus,
      'documents': documents,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'keywords': keywords,
      'galleryImages': galleryImages,
      'adminNotes': adminNotes,
    };
  }

  Provider copyWith({
    String? businessName,
    String? description,
    String? categoryId,
    List<Service>? services,
    String? logoUrl,
    List<String>? images,
    String? websiteUrl,
    double? lat,
    double? lng,
    String? geohash,
    double? serviceAreaKm,
    double? ratingAvg,
    int? ratingCount,
    bool? verified,
    String? verificationStatus,
    Map<String, String>? documents,
    String? status,
    List<String>? keywords,
    List<String>? galleryImages,
    String? adminNotes,
  }) {
    return Provider(
      providerId: providerId,
      ownerUid: ownerUid,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      services: services ?? this.services,
      logoUrl: logoUrl ?? this.logoUrl,
      images: images ?? this.images,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      geohash: geohash ?? this.geohash,
      serviceAreaKm: serviceAreaKm ?? this.serviceAreaKm,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      verified: verified ?? this.verified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      documents: documents ?? this.documents,
      status: status ?? this.status,
      createdAt: createdAt,
      keywords: keywords ?? this.keywords,
      galleryImages: galleryImages ?? this.galleryImages,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  // Convenience getters for document URLs
  String? get nrcUrl => documents['nrcUrl'];
  String? get businessLicenseUrl => documents['businessLicenseUrl'];
  String? get certificatesUrl => documents['certificatesUrl'];
}

