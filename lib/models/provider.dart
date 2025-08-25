import 'package:cloud_firestore/cloud_firestore.dart';

enum ProviderStatus {
  pending,
  verified,
  suspended,
  rejected,
}

enum VerificationStatus {
  notSubmitted,
  pending,
  approved,
  rejected,
}

class Provider {
  final String id;
  final String email;
  final String businessName;
  final String? ownerName;
  final String category;
  final String description;
  final String? phone;
  final String? profileImageUrl;
  final String? businessLogoUrl;
  final Map<String, double>? location; // lat, lng
  final String? address;
  final double? serviceRadius;
  final List<String> serviceAreas;
  final ProviderStatus status;
  final VerificationStatus verificationStatus;
  final List<ServiceOffering> services;
  final Map<String, String>? workingHours; // day -> hours
  final bool isOnline;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActiveAt;
  final List<String>? verificationDocuments;
  final String? pacraRegistration;
  final String? businessLicense;
  final String? websiteUrl; // New field for website URL
  final bool twoFactorEnabled; // New field for 2FA
  final String? twoFactorSecret; // New field for 2FA secret
  final List<String> portfolioImages; // New field for portfolio images
  final Map<String, dynamic>? businessHours; // Enhanced business hours
  final List<String> acceptedPaymentMethods; // New field for payment methods
  final double? minimumOrderAmount; // New field for minimum order
  final bool acceptsEmergencyJobs; // New field for emergency availability
  final int responseTimeMinutes; // New field for average response time

  Provider({
    required this.id,
    required this.email,
    required this.businessName,
    this.ownerName,
    required this.category,
    required this.description,
    this.phone,
    this.profileImageUrl,
    this.businessLogoUrl,
    this.location,
    this.address,
    this.serviceRadius,
    this.serviceAreas = const [],
    required this.status,
    required this.verificationStatus,
    this.services = const [],
    this.workingHours,
    this.isOnline = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.lastActiveAt,
    this.verificationDocuments,
    this.pacraRegistration,
    this.businessLicense,
    this.websiteUrl,
    this.twoFactorEnabled = false,
    this.twoFactorSecret,
    this.portfolioImages = const [],
    this.businessHours,
    this.acceptedPaymentMethods = const [],
    this.minimumOrderAmount,
    this.acceptsEmergencyJobs = false,
    this.responseTimeMinutes = 0,
  });

  factory Provider.fromMap(Map<String, dynamic> data, String id) {
    return Provider(
      id: id,
      email: data['email'] ?? '',
      businessName: data['businessName'] ?? '',
      ownerName: data['ownerName'],
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      phone: data['phone'],
      profileImageUrl: data['profileImageUrl'],
      businessLogoUrl: data['businessLogoUrl'],
      location: data['location'] != null 
          ? Map<String, double>.from(data['location']) 
          : null,
      address: data['address'],
      serviceRadius: data['serviceRadius']?.toDouble(),
      serviceAreas: data['serviceAreas'] != null 
          ? List<String>.from(data['serviceAreas']) 
          : [],
      status: ProviderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ProviderStatus.pending,
      ),
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == data['verificationStatus'],
        orElse: () => VerificationStatus.notSubmitted,
      ),
      services: data['services'] != null
          ? (data['services'] as List).map((s) => ServiceOffering.fromMap(s)).toList()
          : [],
      workingHours: data['workingHours'] != null 
          ? Map<String, String>.from(data['workingHours']) 
          : null,
      isOnline: data['isOnline'] ?? false,
      rating: (data['rating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      lastActiveAt: data['lastActiveAt'] != null 
          ? (data['lastActiveAt'] as Timestamp).toDate() 
          : null,
      verificationDocuments: data['verificationDocuments'] != null 
          ? List<String>.from(data['verificationDocuments']) 
          : null,
      pacraRegistration: data['pacraRegistration'],
      businessLicense: data['businessLicense'],
      websiteUrl: data['websiteUrl'],
      twoFactorEnabled: data['twoFactorEnabled'] ?? false,
      twoFactorSecret: data['twoFactorSecret'],
      portfolioImages: data['portfolioImages'] != null 
          ? List<String>.from(data['portfolioImages']) 
          : [],
      businessHours: data['businessHours'] != null 
          ? Map<String, dynamic>.from(data['businessHours']) 
          : null,
      acceptedPaymentMethods: data['acceptedPaymentMethods'] != null 
          ? List<String>.from(data['acceptedPaymentMethods']) 
          : [],
      minimumOrderAmount: data['minimumOrderAmount']?.toDouble(),
      acceptsEmergencyJobs: data['acceptsEmergencyJobs'] ?? false,
      responseTimeMinutes: data['responseTimeMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'businessName': businessName,
      'ownerName': ownerName,
      'category': category,
      'description': description,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'businessLogoUrl': businessLogoUrl,
      'location': location,
      'address': address,
      'serviceRadius': serviceRadius,
      'serviceAreas': serviceAreas,
      'status': status.name,
      'verificationStatus': verificationStatus.name,
      'services': services.map((s) => s.toMap()).toList(),
      'workingHours': workingHours,
      'isOnline': isOnline,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'verificationDocuments': verificationDocuments,
      'pacraRegistration': pacraRegistration,
      'businessLicense': businessLicense,
      'websiteUrl': websiteUrl,
      'twoFactorEnabled': twoFactorEnabled,
      'twoFactorSecret': twoFactorSecret,
      'portfolioImages': portfolioImages,
      'businessHours': businessHours,
      'acceptedPaymentMethods': acceptedPaymentMethods,
      'minimumOrderAmount': minimumOrderAmount,
      'acceptsEmergencyJobs': acceptsEmergencyJobs,
      'responseTimeMinutes': responseTimeMinutes,
    };
  }
}

class ServiceOffering {
  final String name;
  final String description;
  final double price;
  final String? priceUnit; // per hour, fixed, etc.
  final int estimatedDuration; // in minutes
  final bool isActive;
  final List<String> images; // New field for service images
  final String? category; // New field for service category
  final Map<String, dynamic>? specifications; // New field for service specs
  final bool isPopular; // New field for popular services
  final double? discountPercentage; // New field for discounts

  ServiceOffering({
    required this.name,
    required this.description,
    required this.price,
    this.priceUnit,
    required this.estimatedDuration,
    this.isActive = true,
    this.images = const [],
    this.category,
    this.specifications,
    this.isPopular = false,
    this.discountPercentage,
  });

  factory ServiceOffering.fromMap(Map<String, dynamic> data) {
    return ServiceOffering(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      priceUnit: data['priceUnit'],
      estimatedDuration: data['estimatedDuration'] ?? 60,
      isActive: data['isActive'] ?? true,
      images: data['images'] != null 
          ? List<String>.from(data['images']) 
          : [],
      category: data['category'],
      specifications: data['specifications'] != null 
          ? Map<String, dynamic>.from(data['specifications']) 
          : null,
      isPopular: data['isPopular'] ?? false,
      discountPercentage: data['discountPercentage']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'priceUnit': priceUnit,
      'estimatedDuration': estimatedDuration,
      'isActive': isActive,
      'images': images,
      'category': category,
      'specifications': specifications,
      'isPopular': isPopular,
      'discountPercentage': discountPercentage,
    };
  }
}

