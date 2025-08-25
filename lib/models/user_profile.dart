import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String? address;
  final Map<String, double>? location; // lat, lng
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActiveAt;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String? websiteUrl; // New field for website URL
  final bool twoFactorEnabled; // New field for 2FA
  final String? twoFactorSecret; // New field for 2FA secret
  final List<String> favoriteCategories; // New field for favorite service categories
  final List<String> savedProviders; // New field for saved service providers
  final Map<String, dynamic>? preferences; // New field for user preferences
  final bool acceptsNotifications; // New field for notification preferences
  final String? language; // New field for language preference
  final String? timezone; // New field for timezone preference

  UserProfile({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
    this.address,
    this.location,
    required this.createdAt,
    this.updatedAt,
    this.lastActiveAt,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.websiteUrl,
    this.twoFactorEnabled = false,
    this.twoFactorSecret,
    this.favoriteCategories = const [],
    this.savedProviders = const [],
    this.preferences,
    this.acceptsNotifications = true,
    this.language,
    this.timezone,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String id) {
    return UserProfile(
      id: id,
      email: data['email'] ?? '',
      firstName: data['firstName'],
      lastName: data['lastName'],
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      address: data['address'],
      location: data['location'] != null 
          ? Map<String, double>.from(data['location']) 
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      lastActiveAt: data['lastActiveAt'] != null 
          ? (data['lastActiveAt'] as Timestamp).toDate() 
          : null,
      isEmailVerified: data['isEmailVerified'] ?? false,
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      websiteUrl: data['websiteUrl'],
      twoFactorEnabled: data['twoFactorEnabled'] ?? false,
      twoFactorSecret: data['twoFactorSecret'],
      favoriteCategories: data['favoriteCategories'] != null 
          ? List<String>.from(data['favoriteCategories']) 
          : [],
      savedProviders: data['savedProviders'] != null 
          ? List<String>.from(data['savedProviders']) 
          : [],
      preferences: data['preferences'] != null 
          ? Map<String, dynamic>.from(data['preferences']) 
          : null,
      acceptsNotifications: data['acceptsNotifications'] ?? true,
      language: data['language'],
      timezone: data['timezone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'address': address,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'websiteUrl': websiteUrl,
      'twoFactorEnabled': twoFactorEnabled,
      'twoFactorSecret': twoFactorSecret,
      'favoriteCategories': favoriteCategories,
      'savedProviders': savedProviders,
      'preferences': preferences,
      'acceptsNotifications': acceptsNotifications,
      'language': language,
      'timezone': timezone,
    };
  }

  // Get full name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return 'Unknown User';
  }

  // Get display name (first name or email)
  String get displayName {
    return firstName ?? email.split('@')[0];
  }

  // Check if profile is complete
  bool get isProfileComplete {
    return firstName != null && 
           lastName != null && 
           phoneNumber != null && 
           address != null;
  }

  // Get profile completion percentage
  double get profileCompletionPercentage {
    int completedFields = 0;
    int totalFields = 4; // firstName, lastName, phoneNumber, address
    
    if (firstName != null) completedFields++;
    if (lastName != null) completedFields++;
    if (phoneNumber != null) completedFields++;
    if (address != null) completedFields++;
    
    return completedFields / totalFields;
  }

  // Copy with method for updating fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profileImageUrl,
    String? address,
    Map<String, double>? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActiveAt,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    String? websiteUrl,
    bool? twoFactorEnabled,
    String? twoFactorSecret,
    List<String>? favoriteCategories,
    List<String>? savedProviders,
    Map<String, dynamic>? preferences,
    bool? acceptsNotifications,
    String? language,
    String? timezone,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      address: address ?? this.address,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      twoFactorSecret: twoFactorSecret ?? this.twoFactorSecret,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      savedProviders: savedProviders ?? this.savedProviders,
      preferences: preferences ?? this.preferences,
      acceptsNotifications: acceptsNotifications ?? this.acceptsNotifications,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
    );
  }
}

