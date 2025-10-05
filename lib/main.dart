import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:shared/shared.dart' as shared;
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Notification Service
  await shared.NotificationService.initialize();
  
  runApp(const AllServeApp());
}

class AllServeApp extends StatelessWidget {
  const AllServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<shared.AuthService>(
          create: (_) => shared.AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'All-Serve',
        debugShowCheckedModeBanner: false,
        theme: shared.AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
