# Firebase Database Setup

This document outlines the Firebase Firestore database structure needed for the ALL SERVE app.

## Collections

### 1. categories
Stores service categories that will be randomly displayed.

**Document Structure:**
```json
{
  "icon": "plumbing",
  "label": "Plumbing",
  "description": "Professional plumbing services",
  "active": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Sample Categories:**
- Plumbing
- Auto Repair
- Cleaning
- Electrical
- Carpentry
- Gardening
- Painting
- HVAC

### 2. providers
Stores service provider information with location data.

**Document Structure:**
```json
{
  "name": "John Smith Plumbing",
  "rating": 4.8,
  "reviews": 120,
  "image": "https://example.com/image.jpg",
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060,
    "address": "123 Main St, City, State"
  },
  "services": ["plumbing", "drain_cleaning", "pipe_repair"],
  "active": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### 3. bookings
Stores user booking history to track previous service providers.

**Document Structure:**
```json
{
  "userId": "user123",
  "providerId": "provider456",
  "serviceType": "plumbing",
  "status": "completed",
  "createdAt": "2024-01-01T00:00:00Z",
  "completedAt": "2024-01-01T02:00:00Z"
}
```

## Security Rules

Set up Firestore security rules to control access:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Categories are readable by all authenticated users
    match /categories/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only admin can modify
    }
    
    // Providers are readable by all authenticated users
    match /providers/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only admin can modify
    }
    
    // Users can only read their own bookings
    match /bookings/{document} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
  }
}
```

## Location Permissions

For Android, add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

For iOS, add these keys to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location to find nearby service providers.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location to find nearby service providers.</string>
```

## Testing

1. Create sample categories in the Firestore console
2. Add sample providers with location data
3. Test the app to ensure categories are randomly selected
4. Verify that providers are recommended based on location and previous usage
