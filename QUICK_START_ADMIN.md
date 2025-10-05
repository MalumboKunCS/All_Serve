# 🚀 Quick Start: Admin System Setup

Choose the method that works best for you:

## 🎯 Method 1: Automated Script (Recommended)

### For Windows:
```bash
# Double-click or run:
setup-admin.bat
```

### For Linux/Mac:
```bash
# Make executable and run:
chmod +x setup-admin.sh
./setup-admin.sh
```

### Manual Node.js:
```bash
# Install dependencies
npm install

# Run setup
node setup-admin.js
```

**What you need:**
- Node.js installed
- Firebase service account key JSON file
- Your Firebase Auth UID

---

## 🎯 Method 2: Manual Database Setup

### Step 1: Get Your UID
1. Go to Firebase Console → Authentication → Users
2. Copy your User UID

### Step 2: Create Admin Document
In Firestore, create document in `admins` collection:

```json
{
  "uid": "YOUR_UID_HERE",
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

### Step 3: Create User Document
In Firestore, create document in `users` collection:

```json
{
  "uid": "YOUR_UID_HERE",
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

---

## 🎯 Method 3: Firebase CLI (Advanced)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize project
firebase init firestore

# Use the setup script
node setup-admin.js
```

---

## ✅ After Setup

1. **Deploy security rules:**
```bash
firebase deploy --only firestore:rules
```

2. **Start admin web app:**
```bash
cd admin_web
flutter run -d chrome
```

3. **Login with your admin credentials**

4. **Navigate to Admin Management** to create additional admins

---

## 🔧 Troubleshooting

### "Access denied" error
- Check that both `admins` and `users` documents exist
- Verify `isActive` is `true` in admin document
- Ensure Firestore security rules are deployed

### "Super admin privileges required" error
- Verify `isSuperAdmin` is `true` in admin document
- Only super admins can access Admin Management

### Script errors
- Ensure Node.js is installed
- Check service account key path
- Verify Firebase project configuration

---

## 📞 Need Help?

1. Check the detailed guides:
   - `FIREBASE_CLI_SETUP.md` - Complete CLI setup
   - `ADMIN_SETUP_GUIDE.md` - Manual setup guide

2. Verify your setup:
   - Firebase Console → Firestore → Check documents exist
   - Firebase Console → Authentication → Verify user exists
   - Test login in admin web app

3. Common solutions:
   - Re-run the setup script
   - Check Firestore security rules
   - Verify admin document structure





