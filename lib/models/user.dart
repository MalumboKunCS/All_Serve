import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // "customer" | "provider" | "admin"
  final String? profileImageUrl;
  final Map<String, dynamic>? defaultAddress;
  final List<String> deviceTokens;
  final DateTime createdAt;
  final bool is2FAEnabled;
  final String? twoFactorSecret;
  final List<String> backupCodes;

  User({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.defaultAddress,
    required this.deviceTokens,
    required this.createdAt,
    this.is2FAEnabled = false,
    this.twoFactorSecret,
    this.backupCodes = const [],
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return User(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'customer',
      profileImageUrl: data['profileImageUrl'],
      defaultAddress: data['defaultAddress'],
      deviceTokens: List<String>.from(data['deviceTokens'] ?? []),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      is2FAEnabled: data['is2FAEnabled'] ?? false,
      twoFactorSecret: data['twoFactorSecret'],
      backupCodes: List<String>.from(data['backupCodes'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'defaultAddress': defaultAddress,
      'deviceTokens': deviceTokens,
      'createdAt': Timestamp.fromDate(createdAt),
      'is2FAEnabled': is2FAEnabled,
      'twoFactorSecret': twoFactorSecret,
      'backupCodes': backupCodes,
    };
  }

  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? profileImageUrl,
    Map<String, dynamic>? defaultAddress,
    List<String>? deviceTokens,
    bool? is2FAEnabled,
    String? twoFactorSecret,
    List<String>? backupCodes,
  }) {
    return User(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      defaultAddress: defaultAddress ?? this.defaultAddress,
      deviceTokens: deviceTokens ?? this.deviceTokens,
      createdAt: createdAt,
      is2FAEnabled: is2FAEnabled ?? this.is2FAEnabled,
      twoFactorSecret: twoFactorSecret ?? this.twoFactorSecret,
      backupCodes: backupCodes ?? this.backupCodes,
    );
  }
}



