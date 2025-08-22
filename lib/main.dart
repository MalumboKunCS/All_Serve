import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:all_server/pages/widget_tree.dart';
import 'package:all_server/pages/provider_dashboard.dart';
import 'package:all_server/pages/admin_dashboard.dart';
import 'package:all_server/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service for mobile
  if (!kIsWeb) {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Initialize notification service
    await NotificationService().initialize();
  }
  
  runApp(const MyApp());
}

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALL SERVE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Route based on URL path for web
      home: kIsWeb ? _getWebPage() : const WidgetTree(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _getWebPage() {
    // In a real app, you'd use proper routing
    // For now, check URL manually or use simple routing
    final currentUrl = Uri.base.toString();
    
    if (currentUrl.contains('/admin')) {
      return const AdminDashboard();
    } else {
      return const ProviderDashboard();
    }
  }
}
