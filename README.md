# All-Serve - Local Service Marketplace

A mobile-first marketplace enabling customers in Zambia to find, book, and review verified local service providers. Built with Flutter and Firebase.

## 🚀 Features

- **Customer Mobile App**: Search, book, and review service providers
- **Provider Web Portal**: Manage profiles, services, and bookings
- **Admin Dashboard**: Verify providers and moderate the platform
- **2FA Authentication**: Enhanced security for all users
- **Real-time Notifications**: FCM push notifications
- **Location-based Search**: Find nearby providers
- **Provider Website Integration**: Direct links to provider websites

## 🏗️ Architecture

```
[Customer Flutter App] ←→ [Provider Flutter Web] ←→ [Admin Flutter Web]
                              ↕
                        [Firebase Backend]
                    ├─ Firestore (NoSQL Database)
                    ├─ Storage (Images & Documents)
                    ├─ Auth (2FA Authentication)
                    ├─ Cloud Functions (Server Logic)
                    └─ FCM (Push Notifications)
```

## 🛠️ Tech Stack

- **Frontend**: Flutter (Mobile + Web)
- **Backend**: Firebase (Firestore, Auth, Storage, Functions)
- **Authentication**: Email/Password + 2FA (TOTP)
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Location**: Geolocator + Geohash for proximity queries
- **State Management**: Provider pattern
- **Local Storage**: Hive for caching

## 📈 Current Project Status

### ✅ Completed Components

- **Backend Infrastructure**: Complete Firebase setup with Cloud Functions
- **Authentication System**: Email/password auth with 2FA support + Forgot Password
- **User Registration**: Complete registration flow with role selection and 2FA setup
- **Data Models**: All core models implemented (User, Provider, Booking, Review, Category)
- **Theme System**: Dark purple & blue aesthetic as requested
- **Security Rules**: Comprehensive Firestore and Storage rules
- **Customer Features**: 
  - Home screen with featured categories and nearby providers
  - My Bookings screen with real-time updates
  - Booking management and cancellation
  - Provider detail screens with "Visit Website" functionality
- **Location Services**: GPS location, geocoding, and distance calculations
- **2FA Implementation**: TOTP verification with backup codes

### 🚧 In Progress

- Provider dashboard and service management screens
- Admin verification workflow and provider approval
- Enhanced search and filtering capabilities
- Review and rating system implementation

### ⏳ Next Steps

- Real-time notifications (FCM integration)
- Payment integration placeholder
- File upload system for provider documents
- Chat system between customers and providers
- Advanced geospatial search with geohash
- Performance optimizations and caching

### 🎯 Ready for Testing

The core authentication, user registration, and customer booking flows are complete and ready for testing. The project follows the developer specification requirements with proper 2FA implementation and dark purple/blue theme.

## 📱 Screenshots

*Screenshots will be added as the app is developed*

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.8.1+)
- Dart SDK (3.8.1+)
- Firebase CLI
- Node.js (18+) for Cloud Functions
- Android Studio / VS Code

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/all-serve.git
cd all-serve
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

#### 3.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project named "all-serve"
3. Enable the following services:
   - Authentication (Email/Password)
   - Firestore Database
   - Storage
   - Cloud Functions
   - Cloud Messaging

#### 3.2 Configure Authentication

1. In Firebase Console → Authentication → Sign-in method
2. Enable Email/Password authentication
3. Add custom claims for admin users (see Admin Setup section)

#### 3.3 Configure Firestore

1. Go to Firestore Database → Create Database
2. Start in production mode
3. Choose a location close to Zambia (e.g., europe-west3)
4. Upload the security rules from `firestore.rules`

#### 3.4 Configure Storage

1. Go to Storage → Get Started
2. Choose a location close to Zambia
3. Upload the security rules from `storage.rules`

#### 3.5 Download Configuration Files

1. **Android**: Download `google-services.json` to `android/app/`
2. **iOS**: Download `GoogleService-Info.plist` to `ios/Runner/`
3. **Web**: Copy Firebase config to `lib/firebase_options.dart`

### 4. Cloud Functions Setup

#### 4.1 Install Dependencies

```bash
cd functions
npm install
```

#### 4.2 Deploy Functions

```bash
firebase deploy --only functions
```

#### 4.3 Environment Variables

Set the following environment variables in Firebase Console → Functions → Configuration:

```bash
# Optional: Custom domain for web apps
WEB_DOMAIN=yourdomain.com

# Optional: Email service configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

### 5. Admin Setup

#### 5.1 Create Admin User

1. Create a user account through the app or Firebase Console
2. In Firebase Console → Authentication → Users, find the user
3. Go to Functions → Logs and run this command:

```javascript
// In Firebase Console → Functions → Logs
// Create a custom claim for admin role
const admin = require('firebase-admin');
admin.auth().setCustomUserClaims(uid, {admin: true});
```

#### 5.2 Alternative: Use Firebase CLI

```bash
firebase functions:shell
```

Then run:

```javascript
const admin = require('firebase-admin');
admin.auth().setCustomUserClaims('USER_UID_HERE', {admin: true});
```

### 6. Run the Application

#### 6.1 Mobile App

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios
```

#### 6.2 Web Apps

```bash
# Provider Portal
flutter run -d chrome --web-port 8080

# Admin Dashboard
flutter run -d chrome --web-port 8081
```

#### 6.3 Build for Production

```bash
# Mobile APK
flutter build apk --release

# Web Apps
flutter build web --release
```

## 📊 Database Schema

### Collections

#### users/{uid}
```json
{
  "name": "string",
  "email": "string",
  "phone": "string",
  "role": "customer|provider|admin",
  "profileImageUrl": "string?",
  "defaultAddress": "map?",
  "deviceTokens": ["string"],
  "is2FAEnabled": "boolean",
  "twoFactorSecret": "string?",
  "backupCodes": ["string"],
  "createdAt": "timestamp"
}
```

#### providers/{providerId}
```json
{
  "ownerUid": "string",
  "businessName": "string",
  "description": "string",
  "categoryId": "string",
  "services": ["service"],
  "logoUrl": "string?",
  "images": ["string"],
  "websiteUrl": "string?",
  "lat": "number",
  "lng": "number",
  "geohash": "string",
  "serviceAreaKm": "number",
  "ratingAvg": "number",
  "ratingCount": "number",
  "verified": "boolean",
  "verificationStatus": "pending|approved|rejected",
  "documents": "map",
  "status": "active|suspended|inactive",
  "keywords": ["string"],
  "createdAt": "timestamp"
}
```

#### categories/{categoryId}
```json
{
  "name": "string",
  "iconKey": "string?",
  "iconUrl": "string?",
  "description": "string",
  "isFeatured": "boolean",
  "createdAt": "timestamp"
}
```

#### bookings/{bookingId}
```json
{
  "customerId": "string",
  "providerId": "string",
  "serviceId": "string",
  "address": "map",
  "scheduledAt": "timestamp",
  "requestedAt": "timestamp",
  "status": "requested|accepted|rejected|completed|cancelled",
  "notes": "string?",
  "createdAt": "timestamp"
}
```

#### reviews/{reviewId}
```json
{
  "bookingId": "string",
  "customerId": "string",
  "providerId": "string",
  "rating": "number(1-5)",
  "comment": "string",
  "flagged": "boolean",
  "flagReason": "string?",
  "createdAt": "timestamp"
}
```

## 🔐 Security Features

### Authentication
- Email/password authentication
- Two-factor authentication (TOTP)
- Backup codes for account recovery
- Password reset functionality

### Authorization
- Role-based access control (Customer, Provider, Admin)
- Firestore security rules
- Storage access control
- Cloud Functions authentication

### Data Protection
- Secure document storage
- Encrypted backup codes
- Admin audit logging
- Review moderation system

## 📍 Location Services

### Geohash Implementation
- Spatial indexing for proximity queries
- Efficient radius-based searches
- Distance calculations using Haversine formula

### Search Algorithm
1. **Keyword Matching**: Array-contains queries on provider keywords
2. **Geospatial Filtering**: Bounding box queries using geohash
3. **Ranking**: Distance first, then rating, then review count
4. **Pagination**: Limit results for performance

## 🔔 Notifications

### FCM Integration
- Push notifications for booking updates
- Provider verification status updates
- Admin announcements
- Review notifications

### Notification Types
- **Booking Requests**: New booking notifications for providers
- **Status Updates**: Booking status changes for customers
- **Verification**: Account verification results for providers
- **Announcements**: Platform-wide messages from admins

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Cloud Functions Tests
```bash
cd functions
npm test
```

## 📦 Deployment

### Mobile App
1. **Android**: Build APK and upload to Play Store
2. **iOS**: Build and upload to App Store

### Web Apps
1. **Provider Portal**: Deploy to Firebase Hosting
2. **Admin Dashboard**: Deploy to Firebase Hosting

### Backend
1. **Cloud Functions**: `firebase deploy --only functions`
2. **Security Rules**: `firebase deploy --only firestore:rules,storage:rules`

## 🔧 Configuration

### Environment Variables
```bash
# Firebase
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key

# 2FA
TOTP_ISSUER=All-Serve
TOTP_ALGORITHM=SHA1
TOTP_DIGITS=6
TOTP_PERIOD=30

# Notifications
FCM_SERVER_KEY=your-fcm-server-key
```

### Customization
- **Theme Colors**: Modify `lib/theme/app_theme.dart`
- **App Icons**: Replace assets in `assets/icons/`
- **Splash Screen**: Customize `lib/screens/splash_screen.dart`
- **Business Logic**: Update Cloud Functions in `functions/index.js`

## 📚 API Documentation

### Cloud Functions

#### createBooking
Creates a new booking request.
```javascript
{
  providerId: "string",
  serviceId: "string", 
  scheduledAt: "timestamp",
  address: "map"
}
```

#### updateBookingStatus
Updates booking status (accept/reject/complete/cancel).
```javascript
{
  bookingId: "string",
  action: "accept|reject|complete|cancel"
}
```

#### postReview
Posts a review for a completed booking.
```javascript
{
  bookingId: "string",
  rating: "number(1-5)",
  comment: "string"
}
```

#### fetchProvidersNearby
Fetches providers within specified radius.
```javascript
{
  lat: "number",
  lng: "number", 
  radiusKm: "number",
  categoryId: "string?",
  keywords: "string?"
}
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Firebase Connection Errors
- Verify `google-services.json` is in correct location
- Check Firebase project configuration
- Ensure internet connectivity

#### 2. 2FA Not Working
- Verify TOTP secret generation
- Check time synchronization
- Validate backup codes

#### 3. Location Services
- Check location permissions
- Verify GPS is enabled
- Test with different devices

#### 4. Cloud Functions Deployment
- Check Node.js version (18+)
- Verify Firebase CLI is logged in
- Check function logs for errors

### Debug Mode
```bash
# Enable debug logging
flutter run --debug

# View Firebase logs
firebase functions:log

# Check Firestore rules
firebase firestore:rules:test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/yourusername/all-serve/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/all-serve/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/all-serve/discussions)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for the robust backend services
- Open source community for various packages
- Zambia tech community for inspiration

---

**All-Serve** - Connecting customers with trusted local service providers in Zambia 🇿🇲
