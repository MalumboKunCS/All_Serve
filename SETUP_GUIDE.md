# 🚀 All-Serve Project - Complete Setup Guide

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Flutter Setup](#flutter-setup)
4. [Firebase Setup](#firebase-setup)
5. [Cloud Functions Setup](#cloud-functions-setup)
6. [Database Setup](#database-setup)
7. [File Storage Setup](#file-storage-setup)
8. [Authentication Setup](#authentication-setup)
9. [Push Notifications Setup](#push-notifications-setup)
10. [Running the Application](#running-the-application)
11. [Deployment](#deployment)
12. [Troubleshooting](#troubleshooting)

---

## 🎯 Project Overview

All-Serve is a comprehensive marketplace connecting customers with local service providers in Zambia. The platform includes:

- **📱 Customer Mobile App** - Flutter mobile application
- **💻 Provider Web Portal** - Flutter web application for service providers
- **🔧 Admin Dashboard** - Complete administrative interface
- **☁️ Backend** - Firebase Cloud Functions with Node.js
- **🗄️ Database** - Cloud Firestore with real-time updates
- **📁 Storage** - Firebase Storage for documents and images
- **🔔 Notifications** - Firebase Cloud Messaging (FCM)

---

## ✅ Prerequisites

### Required Software
- **Flutter SDK** (Latest stable version)
- **Node.js** (v16 or higher)
- **Firebase CLI** (Latest version)
- **Android Studio** (for Android development)
- **Xcode** (for iOS development - macOS only)
- **VS Code** or **Android Studio** (IDE)

### Required Accounts
- **Firebase/Google Cloud Account** (with billing enabled)
- **Apple Developer Account** (for iOS deployment)
- **Google Play Console Account** (for Android deployment)

---

## 📱 Flutter Setup

### 1. Install Flutter
```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install
# Add Flutter to your PATH

# Verify installation
flutter doctor
```

### 2. Install Dependencies
```bash
# Navigate to project directory
cd All_Serve

# Get dependencies
flutter pub get

# For iOS (macOS only)
cd ios && pod install
```

### 3. Enable Web Support
```bash
flutter config --enable-web
```

---

## 🔥 Firebase Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `all-serve-zambia`
4. Enable Google Analytics (optional)
5. Create project

### 2. Enable Firebase Services
#### Authentication
1. Go to Authentication → Sign-in method
2. Enable:
   - **Email/Password**
   - **Anonymous** (for guest access)

#### Firestore Database
1. Go to Firestore Database
2. Click "Create database"
3. Choose "Start in test mode" (we'll update rules later)
4. Select location: `africa-south1` (closest to Zambia)

#### Storage
1. Go to Storage
2. Click "Get started"
3. Choose same location as Firestore

#### Cloud Messaging
1. Go to Cloud Messaging
2. No additional setup required initially

### 3. Configure Flutter Apps

#### For Android
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for Android
flutterfire configure --project=all-serve-zambia
```

#### For iOS (macOS only)
```bash
# Configure Firebase for iOS
flutterfire configure --project=all-serve-zambia --platforms=ios
```

#### For Web
```bash
# Configure Firebase for Web
flutterfire configure --project=all-serve-zambia --platforms=web
```

---

## ☁️ Cloud Functions Setup

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools

# Login to Firebase
firebase login
```

### 2. Initialize Functions
```bash
# In project root
firebase init functions

# Select:
# - Use existing project: all-serve-zambia
# - Language: JavaScript
# - ESLint: Yes
# - Install dependencies: Yes
```

### 3. Deploy Functions
```bash
# Navigate to functions directory
cd functions

# Install additional dependencies
npm install firebase-admin firebase-functions speakeasy

# Deploy functions
firebase deploy --only functions
```

### 4. Set Environment Variables
```bash
# Set up environment config
firebase functions:config:set someservice.key="THE API KEY" someservice.id="THE CLIENT ID"

# For 2FA
firebase functions:config:set crypto.secret="your-encryption-secret-key"
```

---

## 🗄️ Database Setup

### 1. Firestore Collections Structure
```
📁 users/
  └── {userId}
      ├── uid: string
      ├── email: string
      ├── name: string
      ├── phone: string
      ├── role: string ('customer' | 'provider' | 'admin')
      ├── profileImageUrl: string?
      ├── deviceTokens: string[]
      ├── twoFactorEnabled: boolean
      ├── backupCodes: string[]
      └── createdAt: timestamp

📁 providers/
  └── {providerId}
      ├── providerId: string
      ├── ownerUid: string
      ├── businessName: string
      ├── description: string
      ├── categoryId: string
      ├── location: {lat: number, lng: number}
      ├── serviceAreaKm: number
      ├── verified: boolean
      ├── verificationStatus: string
      ├── logoUrl: string?
      ├── galleryImages: string[]
      ├── websiteUrl: string?
      ├── services: Service[]
      ├── ratingAvg: number
      ├── ratingCount: number
      └── createdAt: timestamp

📁 categories/
  └── {categoryId}
      ├── categoryId: string
      ├── name: string
      ├── description: string
      ├── iconUrl: string?
      ├── isFeatured: boolean
      ├── tags: string[]
      └── createdAt: timestamp

📁 bookings/
  └── {bookingId}
      ├── bookingId: string
      ├── customerId: string
      ├── providerId: string
      ├── serviceId: string
      ├── status: string
      ├── scheduledAt: timestamp
      ├── address: object
      ├── notes: string?
      ├── createdAt: timestamp
      └── updatedAt: timestamp

📁 reviews/
  └── {reviewId}
      ├── reviewId: string
      ├── bookingId: string
      ├── customerId: string
      ├── providerId: string
      ├── rating: number
      ├── comment: string
      ├── flagged: boolean
      ├── flagReason: string?
      └── createdAt: timestamp

📁 verificationQueue/
  └── {queueId}
      ├── providerId: string
      ├── ownerUid: string
      ├── submittedAt: timestamp
      ├── status: string ('pending' | 'approved' | 'rejected')
      ├── adminNotes: string?
      └── docs: object

📁 announcements/
  └── {announcementId}
      ├── title: string
      ├── message: string
      ├── audience: string
      ├── priority: string
      ├── type: string
      ├── isActive: boolean
      ├── expiresAt: timestamp?
      ├── sentCount: number
      └── createdAt: timestamp

📁 adminAuditLogs/
  └── {logId}
      ├── actorUid: string
      ├── action: string
      ├── detail: object
      └── timestamp: timestamp
```

### 2. Firestore Security Rules
```javascript
// Firestore Rules (firestore.rules)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null && 
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Providers
    match /providers/{providerId} {
      allow read: if true; // Public read
      allow write: if request.auth != null && 
        (resource.data.ownerUid == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Categories - public read, admin write
    match /categories/{categoryId} {
      allow read: if true;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Bookings - customers and providers can read their own
    match /bookings/{bookingId} {
      allow read, write: if request.auth != null && 
        (resource.data.customerId == request.auth.uid || 
         resource.data.providerId == request.auth.uid ||
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Reviews - public read, customers can write
    match /reviews/{reviewId} {
      allow read: if true;
      allow write: if request.auth != null && 
        (resource.data.customerId == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Admin only collections
    match /verificationQueue/{docId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    match /announcements/{docId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    match /adminAuditLogs/{docId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 3. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

---

## 📁 File Storage Setup

### 1. Storage Security Rules
```javascript
// Storage Rules (storage.rules)
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile images
    match /profile_images/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Provider logos
    match /logo_images/{providerId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Gallery images
    match /gallery_images/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Documents (admin and owner access)
    match /documents/{allPaths=**} {
      allow read: if request.auth != null && 
        (request.auth.token.role == 'admin' || request.auth.token.role == 'provider');
      allow write: if request.auth != null;
    }
  }
}
```

### 2. Deploy Storage Rules
```bash
firebase deploy --only storage
```

---

## 🔐 Authentication Setup

### 1. Create Admin User
```bash
# Use Firebase Console to create first admin user
# Go to Authentication → Users → Add user
# Email: admin@allserve.zm
# Set custom claims via Cloud Function or Firebase Admin SDK
```

### 2. Set Custom Claims (via Cloud Function)
```javascript
// Example Cloud Function to set admin role
exports.setAdminRole = functions.https.onCall(async (data, context) => {
  await admin.auth().setCustomUserClaims(data.uid, { role: 'admin' });
  return { success: true };
});
```

---

## 🔔 Push Notifications Setup

### 1. Android Setup
1. Download `google-services.json` from Firebase Console
2. Place in `android/app/`
3. Update `android/app/build.gradle`:
```gradle
dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.0.0'
}
```

### 2. iOS Setup
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to `ios/Runner/` in Xcode
3. Enable Push Notifications capability in Xcode
4. Upload APNs key to Firebase Console

### 3. Web Setup
1. Generate Web Push certificates in Firebase Console
2. Add to `web/index.html`:
```html
<script type="module">
  import { initializeApp } from 'https://www.gstatic.com/firebasejs/9.0.0/firebase-app.js';
  import { getMessaging, getToken } from 'https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging.js';
  
  const firebaseConfig = {
    // Your config
  };
  
  const app = initializeApp(firebaseConfig);
  const messaging = getMessaging(app);
</script>
```

---

## 🚀 Running the Application

### 1. Development Mode
```bash
# Mobile (iOS Simulator)
flutter run -d ios

# Mobile (Android Emulator)
flutter run -d android

# Web (Chrome)
flutter run -d chrome --web-port 3000

# All platforms
flutter run -d all
```

### 2. Build for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release

# Web
flutter build web --release
```

---

## 🌐 Deployment

### 1. Web Deployment (Firebase Hosting)
```bash
# Initialize hosting
firebase init hosting

# Select build/web as public directory
# Configure as SPA: Yes
# Build the web app
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### 2. Android Deployment
1. Upload APK/AAB to Google Play Console
2. Configure app details, screenshots, descriptions
3. Submit for review

### 3. iOS Deployment
1. Archive in Xcode
2. Upload to App Store Connect
3. Configure app details
4. Submit for review

### 4. Cloud Functions Deployment
```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:createBooking
```

---

## 🛠️ Troubleshooting

### Common Issues

#### 1. Firebase Configuration
```bash
# Regenerate firebase_options.dart
flutterfire configure
```

#### 2. Dependencies Issues
```bash
# Clean and reinstall
flutter clean
flutter pub get

# For iOS
cd ios && pod install --repo-update
```

#### 3. Cloud Functions Errors
```bash
# Check logs
firebase functions:log

# Test locally
firebase emulators:start --only functions
```

#### 4. Firestore Permission Denied
- Check security rules
- Verify user authentication
- Ensure custom claims are set

#### 5. Storage Upload Fails
- Check storage rules
- Verify file size limits
- Ensure proper CORS configuration

### Performance Optimization

#### 1. Firestore Indexes
```bash
# Deploy indexes
firebase deploy --only firestore:indexes
```

#### 2. Image Optimization
- Use WebP format for web
- Compress images before upload
- Implement lazy loading

#### 3. Code Splitting (Web)
```dart
// Use deferred imports
import 'package:flutter/widgets.dart' deferred as widgets;
```

### Monitoring & Analytics

#### 1. Firebase Analytics
```dart
// Track events
FirebaseAnalytics.instance.logEvent(
  name: 'search_providers',
  parameters: {'category': 'plumbing'},
);
```

#### 2. Crashlytics
```dart
// Setup crash reporting
FirebaseCrashlytics.instance.recordError(error, stackTrace);
```

---

## 📞 Support

For technical support or questions:
- **Email**: dev@allserve.zm
- **Documentation**: Check inline code comments
- **Issues**: Create GitHub issues for bugs

---

## 📄 License

This project is proprietary software. All rights reserved.

---

**🎉 Congratulations! Your All-Serve marketplace is ready for production!**

