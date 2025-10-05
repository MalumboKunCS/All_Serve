# Admin System Setup Guide

This guide explains how to set up the admin system for the All-Serve application, including creating the first super admin and managing admin users.

## 🚀 Quick Start

### Method 1: Manual Database Setup (Recommended for First Setup)

1. **Open Firebase Console** and go to your project
2. **Navigate to Firestore Database**
3. **Create the first super admin manually:**

```javascript
// In Firestore, create a document in the 'admins' collection
// Document ID: [YOUR_FIREBASE_AUTH_UID]

{
  "uid": "YOUR_FIREBASE_AUTH_UID",
  "email": "admin@yoursite.com",
  "name": "Super Admin",
  "isSuperAdmin": true,
  "createdBy": "system",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "isActive": true,
  "permissions": [
    "manage_admins",
    "manage_users", 
    "manage_providers",
    "manage_reviews",
    "manage_announcements",
    "view_analytics",
    "manage_settings"
  ]
}
```

4. **Create the corresponding user document in the 'users' collection:**

```javascript
// In Firestore, create a document in the 'users' collection
// Document ID: [YOUR_FIREBASE_AUTH_UID]

{
  "uid": "YOUR_FIREBASE_AUTH_UID",
  "name": "Super Admin",
  "email": "admin@yoursite.com",
  "phone": "+1234567890",
  "role": "admin",
  "deviceTokens": [],
  "createdAt": "2024-01-01T00:00:00.000Z",
  "is2FAEnabled": false,
  "backupCodes": []
}
```

### Method 2: Using Firebase CLI

1. **Install Firebase CLI:**
```bash
npm install -g firebase-tools
```

2. **Login to Firebase:**
```bash
firebase login
```

3. **Initialize your project:**
```bash
firebase init firestore
```

4. **Create a setup script:**
```javascript
// setup-admin.js
const admin = require('firebase-admin');
const serviceAccount = require('./path-to-your-service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createSuperAdmin() {
  const adminData = {
    uid: 'YOUR_FIREBASE_AUTH_UID',
    email: 'admin@yoursite.com',
    name: 'Super Admin',
    isSuperAdmin: true,
    createdBy: 'system',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isActive: true,
    permissions: [
      'manage_admins',
      'manage_users',
      'manage_providers', 
      'manage_reviews',
      'manage_announcements',
      'view_analytics',
      'manage_settings'
    ]
  };

  const userData = {
    uid: 'YOUR_FIREBASE_AUTH_UID',
    name: 'Super Admin',
    email: 'admin@yoursite.com',
    phone: '+1234567890',
    role: 'admin',
    deviceTokens: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    is2FAEnabled: false,
    backupCodes: []
  };

  await db.collection('admins').doc('YOUR_FIREBASE_AUTH_UID').set(adminData);
  await db.collection('users').doc('YOUR_FIREBASE_AUTH_UID').set(userData);
  
  console.log('Super admin created successfully!');
}

createSuperAdmin().catch(console.error);
```

5. **Run the script:**
```bash
node setup-admin.js
```

## 🔐 Getting Your Firebase Auth UID

### Method 1: From Firebase Console
1. Go to **Authentication** > **Users**
2. Find your user account
3. Copy the **User UID**

### Method 2: From the App
1. Sign up/login to your app
2. Check the console logs for your UID
3. Or add this temporary code to get your UID:

```dart
// Add this to your app temporarily
print('My UID: ${FirebaseAuth.instance.currentUser?.uid}');
```

## 🛡️ Firestore Security Rules

Update your Firestore security rules to protect admin data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Only admins can access admin collection
    match /admins/{adminId} {
      allow read, write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Only super admins can manage other admins
    match /admins/{adminId} {
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.isSuperAdmin == true;
    }
    
    // Admin audit logs - only admins can read
    match /adminAuditLogs/{logId} {
      allow read: if request.auth != null && 
        exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Other collections...
    match /providers/{providerId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (request.auth.uid == resource.data.ownerUid || 
         exists(/databases/$(database)/documents/admins/$(request.auth.uid)));
    }
  }
}
```

## 📱 Testing the Admin System

1. **Start the admin web app:**
```bash
cd admin_web
flutter run -d chrome
```

2. **Login with your super admin credentials**

3. **Navigate to Admin Management** (only visible to super admins)

4. **Create additional admin users** through the UI

## 🔧 Admin Permissions

### Super Admin Permissions
- `manage_admins` - Create, update, deactivate other admins
- `manage_users` - Manage customer and provider accounts
- `manage_providers` - Approve/reject provider applications
- `manage_reviews` - Moderate reviews and handle flags
- `manage_announcements` - Create and send announcements
- `view_analytics` - Access dashboard analytics
- `manage_settings` - Configure system settings

### Regular Admin Permissions
- `manage_users` - Manage customer and provider accounts
- `manage_providers` - Approve/reject provider applications
- `manage_reviews` - Moderate reviews and handle flags
- `manage_announcements` - Create and send announcements
- `view_analytics` - Access dashboard analytics

## 🚨 Troubleshooting

### "Access denied" error
- Ensure your user document exists in both `users` and `admins` collections
- Check that `isActive` is set to `true` in the admin document
- Verify Firestore security rules are properly configured

### "Super admin privileges required" error
- Ensure `isSuperAdmin` is set to `true` in your admin document
- Only super admins can access the Admin Management tab

### Forgot password not working
- Check that Firebase Authentication is properly configured
- Ensure email templates are set up in Firebase Console
- Verify the email address exists in your system

## 📞 Support

If you encounter issues:
1. Check the browser console for error messages
2. Verify Firestore security rules
3. Ensure all required collections and documents exist
4. Check Firebase Authentication configuration

## 🔄 Next Steps

After setting up the admin system:
1. Create additional admin users as needed
2. Configure admin permissions based on your requirements
3. Set up email templates for password resets
4. Configure Firestore security rules for your specific use case
5. Test all admin functionalities thoroughly





