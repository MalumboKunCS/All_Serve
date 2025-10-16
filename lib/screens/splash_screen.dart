import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart' as shared;
import 'auth/login_screen.dart';
import 'customer/customer_home_screen.dart';
import 'provider/provider_dashboard_screen.dart';
import 'provider/provider_registration_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import '../services/provider_registration_service.dart';
import '../utils/app_logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late Animation<double> _logoAnimation;
  late Animation<double> _fadeAnimation;
  StreamSubscription<shared.User?>? _authSub;

  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _startAnimations();
  }

  void _startAnimations() async {
    await _logoController.forward();
    await _fadeController.forward();
    
    // Wait a bit then check auth state
    await Future.delayed(const Duration(milliseconds: 500));
    _checkAuthState();
  }

  void _checkAuthState() async {
    final authService = context.read<shared.AuthService>();
    
    try {
      // Check current auth state immediately
      final currentUser = authService.currentUser;
      AppLogger.info('SplashScreen: Current user: ${currentUser?.uid}');
      
      if (currentUser != null) {
        // User is already signed in, get their full data
        final userWithData = await authService.getCurrentUserWithData();
        AppLogger.info('SplashScreen: User data from Firestore: ${userWithData?.uid}, role: ${userWithData?.role}');
        if (mounted) {
          _navigateBasedOnUser(userWithData);
        }
      } else {
        // No user signed in, go to login
        AppLogger.info('SplashScreen: No current user, navigating to login');
        if (mounted) {
          _navigateBasedOnUser(null);
        }
      }
      
      // Also listen to future auth state changes
      _authSub = authService.userStream.listen((user) {
        AppLogger.info('SplashScreen: Auth state changed - User: ${user?.uid}, role: ${user?.role}');
        if (mounted) {
          _navigateBasedOnUser(user);
        }
      });
    } catch (e) {
      AppLogger.error('SplashScreen: Error checking auth state: $e');
      if (mounted) {
        _navigateBasedOnUser(null);
      }
    }
  }

  void _navigateBasedOnUser(shared.User? user) async {
    // Check if widget is still mounted before navigation
    if (!mounted) return;
    
    if (user == null) {
      // Navigate to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    } else {
      switch (user.role) {
        case 'customer':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const CustomerHomeScreen(),
            ),
          );
          break;
        case 'provider':
          // Check if provider needs to complete registration
          final needsRegistration = await ProviderRegistrationService.needsRegistrationCompletion(user.uid);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => needsRegistration 
                ? const ProviderRegistrationScreen()
                : const ProviderDashboardScreen(),
            ),
          );
          break;
        case 'admin':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const AdminDashboardScreen(),
            ),
          );
          break;
        default:
          // Unknown role, go to login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
          );
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: shared.AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: shared.AppTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Animation
              ScaleTransition(
                scale: _logoAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.build_circle,
                    size: 80,
                    color: shared.AppTheme.primaryPurple,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // App Name Animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'All-Serve',
                      style: shared.AppTheme.heading1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Local Service Marketplace',
                      style: shared.AppTheme.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha:0.9),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 80),
              
              // Loading Indicator
              FadeTransition(
                opacity: _fadeAnimation,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
