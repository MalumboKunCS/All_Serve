# All-Serve Marketplace

A mobile-first marketplace platform for local service providers in Zambia, built with Flutter and Firebase.

##  Quick Start

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Android Studio / VS Code
- Firebase project
- Cloudinary account

### Installation
# 👨‍💻 Developer Installation Guide
*For Developers Helping Non-Developers Install All-Serve*

## Overview

This guide helps developers install and distribute the All-Serve app for end users who don't have development tools or technical knowledge.

##  Installation Methods

### Method 1: Generate APK for Distribution

#### Step 1: Build Release APK
```bash
# Navigate to project directory
cd all_server

# Build release APK
flutter build apk --release

# The APK will be created at:
# build/app/outputs/flutter-apk/app-release.apk
```

#### Step 2: Distribute APK
1. **Share the APK file** with end users
2. **Provide installation instructions** (see USER_INSTALLATION_GUIDE.md)
3. **Include the APK** in email, cloud storage, or file sharing

### Method 2: Install Directly to User's Device

#### Prerequisites
- User's Android device connected via USB
- USB Debugging enabled on user's device
- Flutter development environment set up

#### Installation Steps
```bash
# 1. Connect user's device via USB
# 2. Enable USB Debugging on device
# 3. Run the app directly to device

flutter run --release
```

### Method 3: Create App Bundle for Play Store

#### Step 1: Build App Bundle
```bash
# Build Android App Bundle
flutter build appbundle --release

# The AAB will be created at:
# build/app/outputs/bundle/release/app-release.aab
```

#### Step 2: Upload to Play Store
1. **Go to Google Play Console**
2. **Create new app** or update existing
3. **Upload the AAB file**
4. **Fill in app details** and screenshots
5. **Submit for review**

## Pre-Installation Setup

### 1. Configure App for Distribution

#### Update App Information
Edit `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        applicationId "com.maluDev.all_server"
        versionCode 1
        versionName "1.0.0"
    }
}
```

#### Update App Name
Edit `android/app/src/main/res/values/strings.xml`:
```xml
<resources>
    <string name="app_name">All-Serve</string>
</resources>
```

### 2. Configure Firebase for Production

#### Update Firebase Configuration
1. **Create production Firebase project**
2. **Download new `google-services.json`**
3. **Replace the file** in `android/app/`
4. **Update `lib/firebase_options.dart`** with new configuration

### 3. Configure Cloudinary for Production

#### Update Cloudinary Settings
Edit `lib/config/cloudinary_config.dart`:
```dart
class CloudinaryConfig {
  static const String cloudName = 'your_production_cloud_name';
  static const String apiKey = 'your_production_api_key';
  static const String apiSecret = 'your_production_api_secret';
  // ... rest of configuration
}
```

##  Installation Checklist

### Before Building
- [ ] **Firebase configured** for production
- [ ] **Cloudinary credentials** updated
- [ ] **App version** incremented
- [ ] **App name** and branding updated
- [ ] **Icons and splash screen** customized
- [ ] **Testing completed** on multiple devices

### During Installation
- [ ] **User's device** is compatible (Android 5.0+)
- [ ] **USB Debugging enabled** (for direct install)
- [ ] **Unknown sources enabled** (for APK install)
- [ ] **Sufficient storage space** available
- [ ] **Internet connection** available for setup

### After Installation
- [ ] **App opens** without crashes
- [ ] **Login/registration** works
- [ ] **Core features** are functional
- [ ] **User can navigate** the app
- [ ] **Database setup** completed (if needed)


##  Troubleshooting Common Issues

### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### Installation Issues
- **"App not installed"** - Check device compatibility
- **"Unknown source"** - Enable in device settings
- **"Storage full"** - Free up space on device
- **"Corrupted file"** - Re-download APK

### Runtime Issues
- **App crashes** - Check logs with `flutter logs`
- **Login issues** - Verify Firebase configuration
- **Image upload fails** - Check Cloudinary credentials
- **Database errors** - Ensure Firestore rules deployed

##  Device Compatibility

### Minimum Requirements
- **Android:** 5.0 (API level 21) or higher
- **RAM:** 2GB minimum, 4GB recommended
- **Storage:** 100MB free space
- **Internet:** Required for app functionality

### Supported Devices
- **Samsung Galaxy** series
- **Google Pixel** series
- **OnePlus** devices
- **Xiaomi** devices
- **Huawei** devices (with Google Services)




## 🔑 Demo Accounts

### Admin Account
- **Email:** `admin@allserve.com`
- **Password:** `admin123456`
- **Access:** Full admin dashboard, database setup, user management

### Customer Account
- **Email:** `customer@example.com`
- **Password:** `password123`
- **Access:** Search providers, create bookings, leave reviews

### Provider Account
- **Email:** `provider@example.com`
- **Password:** `password123`
- **Access:** Manage bookings, upload documents, view earnings

## 📱 Features

### For Customers
-  **Search & Filter** - Find providers by category, location, or keywords
-  **Book Services** - Schedule appointments with verified providers
-  **Rate & Review** - Leave feedback after completed services
-  **Location-based** - Find nearby providers automatically
-  **Notifications** - Real-time updates on booking status

### For Providers
-  **Business Profile** - Create detailed service listings
-  **Document Upload** - Upload verification documents
-  **Analytics** - Track bookings, earnings, and performance
-  **Booking Management** - Accept/reject customer requests
-  **Earnings Tracking** - Monitor income and payment history

### For Admins
-  **User Management** - Monitor all users and providers
-  **Verification** - Review and approve provider documents
-  **Announcements** - Send platform-wide notifications
-  **Analytics** - Platform statistics and insights
-  **Database Setup** - Initialize sample data for testing

##  Project Structure

```
lib/
├── config/                 # Configuration files
│   └── cloudinary_config.dart
├── models/                 # Data models
│   ├── user.dart
│   ├── provider.dart
│   ├── booking.dart
│   ├── review.dart
│   ├── category.dart
│   └── ...
├── screens/               # UI screens
│   ├── auth/             # Authentication screens
│   ├── customer/         # Customer-specific screens
│   ├── provider/         # Provider-specific screens
│   ├── admin/            # Admin dashboard screens
│   └── splash_screen.dart
├── services/             # Business logic services
│   ├── auth_service.dart
│   ├── cloudinary_storage_service.dart
│   ├── booking_service_client.dart
│   └── ...
├── theme/                # App theming
│   └── app_theme.dart
├── utils/                # Utility functions
│   ├── database_setup.dart
│   └── icon_helper.dart
└── main.dart             # App entry point
```

## 🔧 Key Services

### Authentication (`auth_service.dart`)
- User registration and login
- Role-based access control
- Password reset functionality
- Two-factor authentication

### Cloudinary Storage (`cloudinary_storage_service.dart`)
- Image and document uploads
- Automatic optimization and resizing
- CDN delivery for fast loading
- File deletion and management

### Booking Management (`booking_service_client.dart`)
- Create and manage bookings
- Status updates and notifications
- Conflict checking and validation
- Client-side business logic

### Search & Discovery (`search_service.dart`)
- Advanced search with filters
- Location-based provider discovery
- Category and keyword filtering
- Performance-optimized queries

## Database Schema

### Collections

#### `users`
- User profiles and authentication data
- Role-based access (customer, provider, admin)
- Profile images and preferences

#### `providers`
- Service provider business information
- Verification status and documents
- Service offerings and pricing
- Location and availability data

#### `bookings`
- Customer booking requests
- Status tracking and updates
- Scheduling and payment information
- Provider and customer references

#### `reviews`
- Customer feedback and ratings
- Provider performance metrics
- Moderation and flagging system
- Booking validation

#### `categories`
- Service categories and subcategories
- Icons and descriptions
- Featured and trending categories
- Search optimization

## Getting Started with Development


### 1. Testing Features
- **Search:** Use the customer home screen to search for providers
- **Booking:** Create test bookings with different providers
- **Reviews:** Leave reviews after completing bookings
- **Admin:** Use admin account to verify providers and manage users

### 2. Customization
- **Themes:** Modify `lib/theme/app_theme.dart` for custom styling
- **Services:** Add new business logic in `lib/services/`
- **Screens:** Create new UI screens in `lib/screens/`
- **Models:** Extend data models in `lib/models/`

##  Security Features

- **Firestore Security Rules** - Role-based access control
- **Authentication** - Firebase Auth with email/password
- **Data Validation** - Client-side and server-side validation
- **File Upload Security** - Cloudinary with size and type restrictions
- **Admin Controls** - Secure admin-only operations

##  Platform Support

- **Android** - Primary platform with full feature support
- **Web** - Responsive web interface (limited functionality)
- **Desktop** - Windows

##  Development Tools

- **Flutter** - Cross-platform UI framework
- **Firebase** - Backend services and database
- **Cloudinary** - Image and document management
- **Provider** - State management
- **Material Design** - UI components and theming

##  Support

For technical support or questions:
- Check the code documentation in each service file
- Review the database setup process in `lib/utils/database_setup.dart`
- Examine the security rules in `firestore.rules`

## Next Steps

1. **Deploy to Production** - Set up production Firebase and Cloudinary accounts
2. **Add Payment Integration** - Implement payment processing for bookings
3. **Push Notifications** - Enhance notification system with FCM
4. **Analytics** - Add comprehensive analytics and reporting
5. **Mobile App Store** - Prepare for app store deployment

---

**Built with love for the Zambian service provider community**