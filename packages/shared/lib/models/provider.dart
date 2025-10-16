import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String serviceId;
  final String title;
  final double priceFrom;
  final double priceTo;
  final int durationMin;

  Service({
    required this.serviceId,
    required this.title,
    required this.priceFrom,
    required this.priceTo,
    required this.durationMin,
  });

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      serviceId: map['serviceId'] ?? '',
      title: map['title'] ?? '',
      priceFrom: (map['priceFrom'] ?? 0.0).toDouble(),
      priceTo: (map['priceTo'] ?? 0.0).toDouble(),
      durationMin: map['durationMin'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'title': title,
      'priceFrom': priceFrom,
      'priceTo': priceTo,
      'durationMin': durationMin,
    };
  }
}

class Provider {
  final String providerId;
  final String ownerUid;
  final String businessName;
  final String description;
  final String categoryId;
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












