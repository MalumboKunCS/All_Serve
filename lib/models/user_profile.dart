import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? fullName;
  final String? phoneNumber;
  final String? profilePicture;
  final String role; // 'customer', 'provider', 'admin'
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isActive;
  final Map<String, String>? address;

  UserProfile({
    required this.uid,
    required this.email,
    this.fullName,
    this.phoneNumber,
    this.profilePicture,
    required this.role,
    this.preferences = const {},
    required this.createdAt,
    required this.lastActive,
    this.isActive = true,
    this.address,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'],
      phoneNumber: data['phoneNumber'],
      profilePicture: data['profilePicture'],
      role: data['role'] ?? 'customer',
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: (data['lastActive'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      address: data['address'] != null ? Map<String, String>.from(data['address']) : null,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, {String? id}) {
    return UserProfile(
      uid: id ?? data['uid'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'],
      phoneNumber: data['phoneNumber'],
      profilePicture: data['profilePicture'],
      role: data['role'] ?? 'customer',
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      lastActive: data['lastActive'] is Timestamp 
          ? (data['lastActive'] as Timestamp).toDate()
          : DateTime.parse(data['lastActive'] ?? DateTime.now().toIso8601String()),
      isActive: data['isActive'] ?? true,
      address: data['address'] != null ? Map<String, String>.from(data['address']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'profilePicture': profilePicture,
      'role': role,
      'preferences': preferences,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'isActive': isActive,
      'address': address,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'profilePicture': profilePicture,
      'role': role,
      'preferences': preferences,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'isActive': isActive,
      'address': address,
    };
  }

  UserProfile copyWith({
    String? email,
    String? fullName,
    String? phoneNumber,
    String? profilePicture,
    String? role,
    Map<String, dynamic>? preferences,
    DateTime? lastActive,
    bool? isActive,
    Map<String, String>? address,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePicture: profilePicture ?? this.profilePicture,
      role: role ?? this.role,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      isActive: isActive ?? this.isActive,
      address: address ?? this.address,
    );
  }
}