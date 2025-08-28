import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Configure FCM
      await _configureFCM();

      _isInitialized = true;
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  // Request notification permissions
  static Future<bool> _requestPermissions() async {
    if (Platform.isIOS) {
      // iOS permission handling
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } else {
      // Android permission handling
      final status = await Permission.notification.request();
      return status == PermissionStatus.granted;
    }
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Configure FCM
  static Future<void> _configureFCM() async {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is terminated or in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message if app was opened from notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // Get FCM token and save to user document
  static Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Save token to user document
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      // This should be called after user authentication
      // You'll need to get the current user ID from your auth service
      
      // Example implementation:
      // final currentUser = FirebaseAuth.instance.currentUser;
      // if (currentUser != null) {
      //   await FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(currentUser.uid)
      //       .update({
      //     'deviceTokens': FieldValue.arrayUnion([token])
      //   });
      // }
      
      print('FCM Token: $token');
    } catch (e) {
      print('Error saving token to Firestore: $e');
    }
  }

  // Update device token for current user
  static Future<void> updateUserToken(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'deviceTokens': FieldValue.arrayUnion([token])
        });
      }
    } catch (e) {
      print('Error updating user token: $e');
    }
  }

  // Remove device token when user logs out
  static Future<void> removeUserToken(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
            .update({
          'deviceTokens': FieldValue.arrayRemove([token])
        });
      }
    } catch (e) {
      print('Error removing user token: $e');
    }
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification for foreground messages
    await _showLocalNotification(message);
  }

  // Handle notification tap
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('Notification tapped: ${message.messageId}');
    
    // Handle navigation based on notification data
    final data = message.data;
    await _handleNotificationNavigation(data);
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'all_serve_channel',
        'All-Serve Notifications',
        channelDescription: 'Notifications for All-Serve app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'All-Serve',
        message.notification?.body ?? 'You have a new notification',
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  // Handle notification navigation
  static Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String?;
      final id = data['id'] as String?;

      switch (type) {
        case 'booking_request':
          // Navigate to booking management
          print('Navigate to booking: $id');
          break;
        case 'booking_accepted':
        case 'booking_rejected':
        case 'booking_completed':
          // Navigate to booking details
          print('Navigate to booking status: $id');
          break;
        case 'provider_approved':
        case 'provider_rejected':
          // Navigate to provider dashboard
          print('Navigate to provider dashboard');
          break;
        case 'announcement':
          // Navigate to announcements or home
          print('Navigate to announcements');
          break;
        case 'review':
          // Navigate to reviews
          print('Navigate to reviews: $id');
          break;
        default:
          // Navigate to home
          print('Navigate to home');
      }
    } catch (e) {
      print('Error handling notification navigation: $e');
    }
  }

  // Handle notification tap from local notifications
  static void _onNotificationTapped(NotificationResponse response) {
    try {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationNavigation(data);
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  // Subscribe user to role-based topics
  static Future<void> subscribeToRoleTopics(String role) async {
    await subscribeToTopic('all_users');
    await subscribeToTopic('${role}s'); // customers, providers, admins
    
    // Subscribe to general topics
    await subscribeToTopic('announcements');
  }

  // Unsubscribe user from role-based topics
  static Future<void> unsubscribeFromRoleTopics(String role) async {
    await unsubscribeFromTopic('all_users');
    await unsubscribeFromTopic('${role}s');
    await unsubscribeFromTopic('announcements');
  }

  // Get notification settings
  static Future<NotificationSettings> getNotificationSettings() async {
    return await _firebaseMessaging.getNotificationSettings();
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Request notification permissions again
  static Future<bool> requestPermissionsAgain() async {
    return await _requestPermissions();
  }

  // Show system notification settings
  static Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  // Send notification to specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // This would typically be handled by your backend/cloud functions
      // For demonstration, we'll just log it
      print('Sending notification to user $userId: $title - $body');
      
      // In a real implementation, you would:
      // 1. Get user's device tokens from Firestore
      // 2. Send FCM notification via admin SDK (server-side)
      // 3. Or use Cloud Functions to handle this
      
      // Example of how you might get user tokens:
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final deviceTokens = List<String>.from(userData['deviceTokens'] ?? []);
        
        // Here you would use FCM Admin SDK to send to these tokens
        print('Would send to tokens: $deviceTokens');
      }
    } catch (e) {
      print('Error sending notification to user: $e');
    }
  }

  // Send general notification
  static Future<void> sendNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? topic,
  }) async {
    try {
      // This would typically be handled by your backend/cloud functions
      print('Sending notification: $title - $body to topic: $topic');
      
      // In a real implementation, you would use FCM Admin SDK
      // or Cloud Functions to send notifications
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  
  // Handle background notification logic here
  // You can update local database, show notification, etc.
}

// Notification types
class NotificationType {
  static const String bookingRequest = 'booking_request';
  static const String bookingAccepted = 'booking_accepted';
  static const String bookingRejected = 'booking_rejected';
  static const String bookingCompleted = 'booking_completed';
  static const String bookingCancelled = 'booking_cancelled';
  static const String providerApproved = 'provider_approved';
  static const String providerRejected = 'provider_rejected';
  static const String announcement = 'announcement';
  static const String review = 'review';
}

// Notification topics
class NotificationTopic {
  static const String allUsers = 'all_users';
  static const String customers = 'customers';
  static const String providers = 'providers';
  static const String admins = 'admins';
  static const String announcements = 'announcements';
}