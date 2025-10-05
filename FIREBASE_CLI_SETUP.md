# Firebase CLI Admin Setup Guide

This guide walks you through setting up the All-Serve admin system using Firebase CLI and Node.js.

## 🚀 Prerequisites

Before starting, ensure you have:

1. **Node.js** (v14 or higher) - [Download here](https://nodejs.org/)
2. **Firebase CLI** - Install with: `npm install -g firebase-tools`
3. **Firebase Project** - Your All-Serve project must be created
4. **Service Account Key** - Downloaded from Firebase Console

## 📋 Step-by-Step Setup

### Step 1: Install Dependencies

```bash
# Install required packages
npm install firebase-admin

# Or use the provided package.json
npm install
```

### Step 2: Get Your Firebase Service Account Key

1. **Go to Firebase Console** → Your Project → Project Settings
2. **Navigate to Service Accounts** tab
3. **Click "Generate new private key"**
4. **Download the JSON file** (keep it secure!)
5. **Save it in your project directory** (e.g., `service-account-key.json`)

### Step 3: Get Your Firebase Auth UID

You need your Firebase Auth UID. Here are several ways to get it:

#### Method A: From Firebase Console
1. Go to **Authentication** → **Users**
2. Find your user account
3. Copy the **User UID**

#### Method B: From Your App
1. Add this temporary code to your Flutter app:
```dart
print('My UID: ${FirebaseAuth.instance.currentUser?.uid}');
```
2. Run the app and check console logs

#### Method C: Create a New User
1. Use Firebase Console → Authentication → Add User
2. Copy the generated UID

### Step 4: Run the Setup Script

```bash
# Run the setup script
node setup-admin.js

# Or use npm script
npm run setup
```

### Step 5: Follow the Interactive Prompts

The script will ask you for:

```
🚀 All-Serve Admin Setup Script
================================

Enter the path to your Firebase service account key JSON file: service-account-key.json
✅ Firebase Admin initialized successfully!

📝 Enter Super Admin Details:
================================
Firebase Auth UID: your-uid-here
Email address: admin@yoursite.com
Full name: Super Admin
Phone number (optional): +1234567890

📋 Confirm Details:
   UID: your-uid-here
   Name: Super Admin
   Email: admin@yoursite.com
   Phone: +1234567890

Proceed with creating super admin? (y/N): y
```

### Step 6: Deploy Security Rules

After the script completes, deploy the generated security rules:

```bash
# Deploy Firestore security rules
firebase deploy --only firestore:rules
```

## 🔧 What the Script Does

The setup script automatically:

1. **Initializes Firebase Admin SDK** with your service account
2. **Creates Admin Document** in the `admins` collection with:
   - Super admin privileges
   - Full permissions
   - System creation timestamp
3. **Creates User Document** in the `users` collection with:
   - Admin role
   - Complete user profile
4. **Generates Security Rules** for Firestore protection
5. **Creates Audit Log** entry for the creation
6. **Verifies Creation** to ensure everything worked

## 📁 Generated Files

After running the script, you'll have:

- `firestore.rules` - Firestore security rules
- Console output with admin details
- Verification of successful creation

## 🛡️ Security Rules Generated

The script creates comprehensive Firestore security rules:

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
    
    // Additional rules for providers, bookings, reviews, announcements...
  }
}
```

## 🧪 Testing the Setup

After running the script:

1. **Start your admin web app:**
```bash
cd admin_web
flutter run -d chrome
```

2. **Login with your admin credentials**

3. **Verify access:**
   - You should see the Admin Management tab
   - You should be able to create additional admins
   - All admin features should be accessible

## 🔍 Troubleshooting

### Common Issues:

#### "firebase-admin package not found"
```bash
npm install firebase-admin
```

#### "Cannot find module" error
```bash
# Make sure you're in the correct directory
ls -la setup-admin.js

# Install dependencies
npm install
```

#### "Permission denied" error
- Check your service account key path
- Ensure the JSON file is valid
- Verify Firebase project ID matches

#### "Admin created but verification failed"
- Check Firebase Console for the documents
- Verify Firestore rules are deployed
- Check for any permission issues

### Debug Mode:

Run with debug logging:
```bash
DEBUG=* node setup-admin.js
```

## 🔐 Security Notes

- **Keep your service account key secure** - Never commit it to version control
- **Use environment variables** for production:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"
```
- **Rotate keys regularly** for security
- **Limit service account permissions** to minimum required

## 📞 Support

If you encounter issues:

1. **Check the console output** for specific error messages
2. **Verify Firebase project configuration**
3. **Ensure all prerequisites are installed**
4. **Check Firestore security rules deployment**

## 🎯 Next Steps

After successful setup:

1. **Deploy security rules**: `firebase deploy --only firestore:rules`
2. **Test admin login** in your web app
3. **Create additional admins** through the UI
4. **Configure admin permissions** as needed
5. **Set up email templates** for password resets

## 📚 Additional Resources

- [Firebase Admin SDK Documentation](https://firebase.google.com/docs/admin)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase CLI Documentation](https://firebase.google.com/docs/cli)





