import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'package:shared/shared.dart' as shared;
import 'screens/auth/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final authService = shared.AuthService();

  runApp(AdminWebApp(authService: authService));
}

class AdminWebApp extends StatelessWidget {
  final shared.AuthService authService;

  const AdminWebApp({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<shared.AuthService>.value(value: authService),
      ],
      child: MaterialApp(
        title: 'All-Serve Admin Dashboard',
        debugShowCheckedModeBanner: false,
        theme: shared.AppTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<shared.AuthService>(
      builder: (context, authService, child) {
        return StreamBuilder(
          stream: authService.userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: shared.AppTheme.backgroundDark,
                body: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final user = snapshot.data;
            if (user != null && user.role == 'admin') {
              return const AdminDashboardScreen();
            } else {
              return const AdminLoginScreen();
            }
          },
        );
      },
    );
  }
}