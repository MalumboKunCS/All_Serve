# Google Maps Integration Setup Guide

## 🗺️ Overview
This guide explains how to set up Google Maps integration for the provider location selection feature in All-Serve.

## 📋 Prerequisites
- Google Cloud Platform account
- Flutter project with Google Maps dependencies

## 🔧 Setup Steps

### 1. Enable Google Maps APIs
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Geocoding API**
   - **Places API** (optional, for search functionality)

### 2. Create API Keys
1. Go to "Credentials" in Google Cloud Console
2. Click "Create Credentials" → "API Key"
3. Create separate keys for:
   - **Android**: Restrict to Android apps
   - **iOS**: Restrict to iOS apps

### 3. Configure Android
Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_ACTUAL_ANDROID_API_KEY"/>
```

### 4. Configure iOS (if needed)
Add to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 5. Install Dependencies
Run the following command:

```bash
flutter pub get
```

### 6. Test the Integration
1. Run the app: `flutter run`
2. Navigate to Provider Registration
3. Go to Location page
4. Tap "Select on Map"
5. Verify Google Maps loads and location selection works

## 🎯 Features Implemented

### Google Maps Location Picker
- **Interactive Map**: Users can tap/drag to select location
- **Current Location**: Get user's current location with one tap
- **Address Lookup**: Automatic address resolution from coordinates
- **Visual Feedback**: Red marker shows selected location
- **Confirmation**: Clear confirmation button with location details

### Provider Registration Integration
- **Map Button**: "Select on Map" button replaces GPS-only approach
- **Location Display**: Shows selected address and coordinates
- **Visual Confirmation**: Green success indicator when location is selected
- **Validation**: Ensures location is selected before proceeding

## 🔒 Security Best Practices

### API Key Restrictions
1. **Android**: Restrict by package name and SHA-1 certificate fingerprint
2. **iOS**: Restrict by bundle identifier
3. **API Restrictions**: Limit to only required APIs (Maps SDK, Geocoding)

### Example Restrictions:
```
Android Package Name: com.example.all_server
iOS Bundle ID: com.example.allServer
APIs: Maps SDK for Android, Maps SDK for iOS, Geocoding API
```

## 🚀 Benefits

### User Experience
- **Intuitive**: Visual map selection vs. GPS coordinates
- **Accurate**: Pinpoint exact business location
- **Flexible**: Works without GPS (manual selection)
- **Informative**: Shows readable address

### Developer Benefits
- **Easy Integration**: Simple widget-based implementation
- **Customizable**: Easy to modify map appearance and behavior
- **Scalable**: Can be reused in other parts of the app
- **Maintainable**: Clean separation of concerns

## 🐛 Troubleshooting

### Common Issues
1. **Map not loading**: Check API key configuration
2. **Location not working**: Verify location permissions
3. **Address lookup failing**: Ensure Geocoding API is enabled
4. **Performance issues**: Consider map optimization settings

### Debug Steps
1. Check console for API key errors
2. Verify network connectivity
3. Test on physical device (not emulator)
4. Check Google Cloud Console for API usage

## 📱 Usage Example

```dart
// Navigate to map picker
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GoogleMapsLocationPicker(
      onLocationSelected: (LatLng position, String address) {
        // Handle selected location
        print('Selected: $address at $position');
      },
    ),
  ),
);
```

## 🔄 Future Enhancements
- **Search Integration**: Add Places API for location search
- **Offline Support**: Cache map tiles for offline use
- **Custom Markers**: Business-specific marker icons
- **Multiple Locations**: Support for multiple business locations
- **Route Planning**: Show routes to business location

## 📞 Support
For issues with Google Maps integration:
1. Check Google Maps documentation
2. Review API quotas and billing
3. Verify API key restrictions
4. Test with minimal implementation first





