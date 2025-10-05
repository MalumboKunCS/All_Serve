# 🚀 All-Serve Quick Start Guide

## ⚡ Get Running in 5 Minutes

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Cloudinary
Edit `lib/config/cloudinary_config.dart`:
```dart
class CloudinaryConfig {
  static const String cloudName = 'your_cloud_name';
  static const String apiKey = 'your_api_key';
  static const String apiSecret = 'your_api_secret';
  // ... rest stays the same
}
```

### 3. Deploy Firebase Rules
```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### 4. Run the App
```bash
flutter run
```

### 5. Initialize Database
1. Login as admin: `admin@allserve.com` / `admin123456`
2. Go to Admin Dashboard → Database Setup tab
3. Click "Complete Database Setup"
4. Wait for completion

#

## 🎯 Test the Features

### Customer Flow
1. Login as customer
2. Search for providers
3. View provider details
4. Create a booking
5. Leave a review

### Provider Flow
1. Login as provider
2. View dashboard
3. Manage bookings
4. Upload documents

### Admin Flow
1. Login as admin
2. Review verifications
3. Manage users
4. Send announcements

## Troubleshooting

### Common Issues
- **Login stuck:** Check Firebase Auth configuration
- **Images not uploading:** Verify Cloudinary credentials
- **Database errors:** Ensure Firestore rules are deployed
- **Build errors:** Run `flutter clean && flutter pub get`

### Need Help?
- Check `README.md` for detailed setup
- Review `CODE_STRUCTURE.md` for architecture
- Check Firebase Console for errors
- Verify Cloudinary dashboard for uploads

---

**Ready to go!
