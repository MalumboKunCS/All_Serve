import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'two_fa_verification_screen.dart';
import '../customer/customer_home_screen.dart';
import '../provider/provider_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
// Post-login navigation is handled by SplashScreen via auth state listener

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('LoginScreen: Starting login process for ${_emailController.text.trim()}');
      final authService = context.read<AuthService>();
      
      final credential = await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      print('LoginScreen: Login successful, credential: ${credential.user?.uid}');
      
      // Check if user document exists in Firestore
      final userWithData = await authService.getCurrentUserWithData();
      print('LoginScreen: User data from Firestore: ${userWithData?.uid}, role: ${userWithData?.role}');
      
      if (userWithData == null) {
        throw Exception('User profile not found. Please contact support.');
      }
      
      // Navigate based on role immediately so we leave the login page
      print('LoginScreen: Login completed successfully');
      if (!mounted) return;
      final role = (userWithData.role).toLowerCase();
      Widget destination;
      switch (role) {
        case 'provider':
          destination = const ProviderDashboardScreen();
          break;
        case 'admin':
          destination = const AdminDashboardScreen();
          break;
        case 'customer':
        default:
          destination = const CustomerHomeScreen();
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
      
    } catch (e) {
      print('LoginScreen: Login error: $e');
      setState(() => _isLoading = false);
      
      if (e.toString().contains('2FA_REQUIRED')) {
        // Navigate to 2FA verification
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TwoFAVerificationScreen(
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
              ),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.contains('user-not-found')) {
            errorMessage = 'No user found with this email address.';
          } else if (errorMessage.contains('wrong-password')) {
            errorMessage = 'Incorrect password.';
          } else if (errorMessage.contains('invalid-email')) {
            errorMessage = 'Invalid email address.';
          } else if (errorMessage.contains('user-disabled')) {
            errorMessage = 'This account has been disabled.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: $errorMessage'),
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and Title
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.build_circle,
                      size: 60,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    'Welcome Back',
                    style: AppTheme.heading1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Sign in to continue to All-Serve',
                    style: AppTheme.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email, color: AppTheme.textSecondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock, color: AppTheme.textSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.accentBlue,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Login Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: AppTheme.primaryButtonStyle,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: AppTheme.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Sign Up',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.accentPurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


