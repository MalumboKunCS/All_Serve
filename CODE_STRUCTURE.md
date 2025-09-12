# All-Serve Code Structure Documentation

## 📁 Project Architecture

This Flutter application follows a clean architecture pattern with clear separation of concerns:

```
lib/
├── config/                 # Configuration and constants
├── models/                 # Data models and entities
├── screens/               # UI screens and widgets
├── services/              # Business logic and data access
├── theme/                 # App theming and styling
├── utils/                 # Utility functions and helpers
└── main.dart             # Application entry point
```

##  Configuration Layer (`config/`)

### `cloudinary_config.dart`
- **Purpose:** Cloudinary service configuration
- **Key Components:**
  - API credentials (cloudName, apiKey, apiSecret)
  - Upload presets for different file types
  - Base URLs and transformation settings
- **Usage:** Centralized configuration for image/document uploads

##  Data Models (`models/`)

### Core Models

#### `user.dart`
- **Purpose:** User authentication and profile data
- **Key Fields:**
  - `uid`, `email`, `fullName`, `role`
  - `profileImageUrl`, `phoneNumber`, `address`
  - `createdAt`, `lastActive`, `isActive`
- **Roles:** customer, provider, admin

#### `provider.dart`
- **Purpose:** Service provider business information
- **Key Fields:**
  - `providerId`, `businessName`, `description`
  - `categoryId`, `services[]`, `images[]`
  - `location` (lat/lng), `serviceAreaKm`
  - `verificationStatus`, `documents{}`
- **Features:** Service offerings, gallery images, verification docs

#### `booking.dart`
- **Purpose:** Customer booking requests and management
- **Key Fields:**
  - `bookingId`, `customerId`, `providerId`
  - `serviceId`, `scheduledAt`, `status`
  - `estimatedPrice`, `finalPrice`, `notes`
- **Status Flow:** pending → accepted → inProgress → completed

#### `review.dart`
- **Purpose:** Customer feedback and ratings
- **Key Fields:**
  - `reviewId`, `bookingId`, `customerId`, `providerId`
  - `rating` (1-5), `comment`, `createdAt`
  - `flagged`, `moderated`
- **Validation:** Only completed bookings can be reviewed

#### `category.dart`
- **Purpose:** Service categories and classifications
- **Key Fields:**
  - `categoryId`, `name`, `description`
  - `iconKey`, `isFeatured`, `createdAt`
- **Usage:** Provider categorization and search filtering

### Supporting Models

#### `announcement.dart`
- **Purpose:** Admin announcements and notifications
- **Key Fields:** `title`, `message`, `targetAudience`, `createdAt`

#### `verification_queue.dart`
- **Purpose:** Provider verification workflow
- **Key Fields:** `providerId`, `documents[]`, `status`, `submittedAt`

#### `admin_audit_log.dart`
- **Purpose:** Admin action tracking and auditing
- **Key Fields:** `action`, `adminId`, `targetId`, `timestamp`, `details`

## 🖥️ UI Screens (`screens/`)

### Authentication (`auth/`)

#### `login_screen.dart`
- **Purpose:** User authentication and role-based navigation
- **Features:**
  - Email/password login
  - Role detection (customer/provider/admin)
  - Automatic navigation to appropriate dashboard
  - Loading states and error handling

#### `register_screen.dart`
- **Purpose:** New user registration
- **Features:**
  - Form validation
  - Role selection
  - Profile creation
  - Email verification

#### `forgot_password_screen.dart`
- **Purpose:** Password reset functionality
- **Features:**
  - Email validation
  - Firebase password reset
  - Success/error feedback

#### `two_fa_verification_screen.dart`
- **Purpose:** Two-factor authentication
- **Features:**
  - OTP input and validation
  - Secure storage integration
  - Timeout handling

### Customer Screens (`customer/`)

#### `customer_home_screen.dart`
- **Purpose:** Main customer dashboard
- **Features:**
  - Featured categories
  - Recent bookings
  - Quick search
  - Profile management

#### `advanced_search_screen.dart`
- **Purpose:** Advanced provider search and filtering
- **Features:**
  - Keyword search with debouncing
  - Category filtering
  - Feature keyword selection (1-3 max)
  - Location-based results
  - Performance optimization with background isolates

#### `provider_detail_screen.dart`
- **Purpose:** Detailed provider information
- **Features:**
  - Provider profile and services
  - Gallery images
  - Reviews and ratings
  - Booking creation

#### `booking_screen.dart`
- **Purpose:** Create new service bookings
- **Features:**
  - Service selection
  - Date/time picker
  - Price estimation
  - Notes and special requests

#### `my_bookings_screen.dart`
- **Purpose:** Customer booking management
- **Features:**
  - Booking history
  - Status tracking
  - Cancellation options
  - Review prompts

#### `review_screen.dart`
- **Purpose:** Leave reviews for completed services
- **Features:**
  - Star rating system
  - Comment input
  - Photo uploads
  - Validation (completed bookings only)

### Provider Screens (`provider/`)

#### `provider_dashboard_screen.dart`
- **Purpose:** Provider business dashboard
- **Features:**
  - Earnings overview
  - Booking statistics
  - Recent activity
  - Quick actions

#### `provider_bookings_screen.dart`
- **Purpose:** Manage incoming booking requests
- **Features:**
  - Pending bookings list
  - Accept/reject actions
  - Status updates
  - Customer communication

#### `provider_profile_screen.dart`
- **Purpose:** Business profile management
- **Features:**
  - Business information
  - Service offerings
  - Gallery management
  - Contact details

#### `provider_documents_screen.dart`
- **Purpose:** Verification document management
- **Features:**
  - Document upload
  - Status tracking
  - Admin feedback
  - Re-submission options

### Admin Screens (`admin/`)

#### `admin_dashboard_screen.dart`
- **Purpose:** Platform administration dashboard
- **Features:**
  - Platform statistics
  - Quick actions
  - Tabbed interface
  - Real-time data

#### `admin_verification_queue_screen.dart`
- **Purpose:** Provider verification management
- **Features:**
  - Pending verifications
  - Document viewing
  - Approve/reject actions
  - Admin comments

#### `admin_providers_screen.dart`
- **Purpose:** Provider management
- **Features:**
  - Provider listings
  - Status management
  - Document access
  - Performance metrics

#### `database_setup_screen.dart`
- **Purpose:** Database initialization and management
- **Features:**
  - Sample data creation
  - Database reset
  - Admin user creation
  - Progress tracking

## 🔧 Services Layer (`services/`)

### Authentication Services

#### `auth_service.dart`
- **Purpose:** User authentication and session management
- **Key Methods:**
  - `signInWithEmailAndPassword()`
  - `createUserWithEmailAndPassword()`
  - `signOut()`
  - `getCurrentUser()`
- **Features:** Role-based access, profile creation, session persistence

#### `two_factor_service.dart`
- **Purpose:** Two-factor authentication implementation
- **Key Methods:**
  - `generateOTP()`
  - `verifyOTP()`
  - `storeOTP()`
- **Security:** Secure storage, time-based validation

### Storage Services

#### `cloudinary_storage_service.dart`
- **Purpose:** Image and document upload management
- **Key Methods:**
  - `uploadImage()`
  - `uploadProfileImage()`
  - `uploadProviderLogo()`
  - `uploadDocument()`
  - `deleteImage()`
- **Features:** Automatic optimization, CDN delivery, file validation

#### `cloudinary_file_upload_service.dart`
- **Purpose:** User-friendly file upload interface
- **Key Methods:**
  - `uploadProfileImage()`
  - `uploadGalleryImages()`
  - `uploadVerificationDocuments()`
- **Features:** File validation, progress tracking, error handling

### Business Logic Services

#### `booking_service_client.dart`
- **Purpose:** Booking management (replaces Cloud Functions)
- **Key Methods:**
  - `createBooking()`
  - `updateBookingStatus()`
  - `getUserBookings()`
- **Features:** Client-side validation, conflict checking, status management

#### `review_service_client.dart`
- **Purpose:** Review management (replaces Cloud Functions)
- **Key Methods:**
  - `createReview()`
  - `updateReview()`
  - `getProviderReviews()`
- **Features:** Rating calculation, duplicate prevention, moderation

#### `admin_service_client.dart`
- **Purpose:** Admin operations (replaces Cloud Functions)
- **Key Methods:**
  - `approveProvider()`
  - `rejectProvider()`
  - `sendAnnouncement()`
- **Features:** Audit logging, notification sending, status updates

### Data Access Services

#### `provider_service.dart`
- **Purpose:** Provider data management
- **Key Methods:**
  - `getProvider()`
  - `createProvider()`
  - `updateProvider()`
  - `searchProviders()`
- **Features:** Location-based search, category filtering, performance optimization

#### `search_service.dart`
- **Purpose:** Advanced search and discovery
- **Key Methods:**
  - `searchProviders()`
  - `searchByCategory()`
  - `searchByLocation()`
- **Features:** Keyword matching, relevance scoring, background processing

#### `profile_service.dart`
- **Purpose:** User profile management
- **Key Methods:**
  - `getUserProfile()`
  - `updateUserProfile()`
  - `uploadProfileImage()`
- **Features:** Profile updates, image management, data validation

### Utility Services

#### `notification_service.dart`
- **Purpose:** Push notification management
- **Key Methods:**
  - `initializeNotifications()`
  - `sendNotification()`
  - `handleBackgroundMessage()`
- **Features:** FCM integration, background handling, user targeting

#### `location_service.dart`
- **Purpose:** Location and geolocation services
- **Key Methods:**
  - `getCurrentLocation()`
  - `requestLocationPermission()`
  - `calculateDistance()`
- **Features:** Permission handling, GPS integration, distance calculations

##  Theming (`theme/`)

### `app_theme.dart`
- **Purpose:** Centralized app theming and styling
- **Components:**
  - Color schemes (dark theme)
  - Typography styles
  - Button styles
  - Card styles
  - Spacing and sizing constants
- **Features:** Consistent design system, easy customization

##  Utilities (`utils/`)

### `database_setup.dart`
- **Purpose:** Database initialization and sample data creation
- **Key Methods:**
  - `initializeDatabase()`
  - `setupCompleteDatabase()`
  - `createSampleData()`
- **Features:** Admin user creation, sample providers, test data

### `icon_helper.dart`
- **Purpose:** Icon management and mapping
- **Features:** Category icons, service icons, dynamic icon selection

##  State Management

The app uses **Provider** for state management:

- **AuthService:** User authentication state
- **LocationService:** Location and permission state
- **NotificationService:** Notification state

##  Database Integration

### Firestore Collections
- **users:** User profiles and authentication
- **providers:** Service provider data
- **bookings:** Booking requests and management
- **reviews:** Customer feedback and ratings
- **categories:** Service categories
- **announcements:** Admin announcements
- **verificationQueue:** Provider verification workflow
- **auditLogs:** Admin action tracking

### Security Rules
- **Role-based access control**
- **Data validation at database level**
- **Secure file upload restrictions**
- **Business logic enforcement**

##  Performance Optimizations

### UI Performance
- **Debounced search input** (350ms delay)
- **Background isolates** for CPU-intensive tasks
- **CachedNetworkImage** for efficient image loading
- **ListView.builder** for large lists
- **Deferred initialization** for startup performance

### Data Performance
- **Composite indexes** for complex queries
- **Pagination** for large datasets
- **Caching** for frequently accessed data
- **Optimized queries** with proper filtering

##  Security Features

### Authentication
- **Firebase Auth** with email/password
- **Role-based access control**
- **Two-factor authentication**
- **Secure session management**

### Data Security
- **Firestore security rules**
- **Input validation** on client and server
- **File upload restrictions**
- **Admin action auditing**

### API Security
- **Cloudinary signed uploads**
- **Rate limiting** and abuse prevention
- **Secure credential storage**
- **HTTPS enforcement**

##  Platform Support

### Android
- **Full feature support**
- **Material Design** components
- **Native performance**
- **Google Play** ready

### iOS
- **Full compatibility**
- **Cupertino design** elements
- **iOS-specific optimizations**
- **App Store** ready

### Web
- **Responsive design**
- **Limited functionality**
- **Progressive Web App** features

##  Testing Strategy

### Unit Tests
- **Service layer** testing
- **Model validation** testing
- **Utility function** testing

### Widget Tests
- **UI component** testing
- **User interaction** testing
- **State management** testing

### Integration Tests
- **End-to-end** user flows
- **Database integration** testing
- **API integration** testing

---

This documentation provides a comprehensive overview of the All-Serve codebase structure, helping developers understand the architecture, components, and relationships within the application.
