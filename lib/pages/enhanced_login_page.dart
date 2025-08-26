import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/services/two_factor_service.dart';
import 'package:all_server/services/password_reset_service.dart';
import 'package:all_server/pages/profile_setup_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

class EnhancedLoginPage extends StatefulWidget {
  const EnhancedLoginPage({super.key});

  @override
  State<EnhancedLoginPage> createState() => _EnhancedLoginPageState();
}

class _EnhancedLoginPageState extends State<EnhancedLoginPage>
    with TickerProviderStateMixin {
  String? errorMessage = '';
  bool isLogin = true;
  bool isLoading = false;
  bool isPasswordVisible = false;
  bool is2FAEnabled = false;
  bool show2FAField = false;
  String? userId;
  String? userEmail;

  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();
  final TextEditingController _controller2FA = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    _controller2FA.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> signInWithEmailAndPassword() async {
    if (_controllerEmail.text.isEmpty || _controllerPassword.text.isEmpty) {
      setState(() => errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await Auth().signInWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );

      // Check if 2FA is enabled for this user
      User? user = Auth().currentUser;
      if (user != null) {
        bool has2FA = await TwoFactorService.is2FAEnabled(user.uid);
        if (has2FA) {
          setState(() {
            is2FAEnabled = true;
            show2FAField = true;
            userId = user.uid;
            userEmail = _controllerEmail.text;
          });
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = _getErrorMessage(e.code));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> verify2FA() async {
    if (_controller2FA.text.isEmpty) {
      setState(() => errorMessage = 'Please enter the 2FA code');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      bool isValid = await TwoFactorService.verifyOTP(
        userId: userId!,
        otp: _controller2FA.text,
      );

      if (isValid) {
        // Navigate to home page
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() => errorMessage = 'Invalid 2FA code. Please try again.');
      }
    } catch (e) {
      setState(() => errorMessage = 'Error verifying 2FA code');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    if (_controllerEmail.text.isEmpty || _controllerPassword.text.isEmpty) {
      setState(() => errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await Auth().createUserWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileSetupPage(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = _getErrorMessage(e.code));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> forgotPassword() async {
    if (_controllerEmail.text.isEmpty) {
      setState(() => errorMessage = 'Please enter your email address');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      bool success = await PasswordResetService.sendPasswordResetEmail(
        _controllerEmail.text,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent! Check your inbox.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => errorMessage = 'Failed to send reset email. Please try again.');
      }
    } catch (e) {
      setState(() => errorMessage = 'Error sending reset email');
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      isPasswordVisible = !isPasswordVisible;
    });
  }

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      errorMessage = '';
      show2FAField = false;
      is2FAEnabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo and Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.build_circle,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ALL SERVE',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin ? 'Welcome back!' : 'Create your account',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Form Fields
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Email Field
                        TextField(
                          controller: _controllerEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email address',
                            prefixIcon: Icon(Icons.email, color: Colors.blue.shade600),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Password Field
                        TextField(
                          controller: _controllerPassword,
                          obscureText: !isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(Icons.lock, color: Colors.blue.shade600),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: _togglePasswordVisibility,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        
                        // 2FA Field
                        if (show2FAField) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Two-Factor Authentication',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OtpTextField(
                            numberOfFields: 6,
                            fieldWidth: 45,
                            borderColor: Colors.blue.shade600,
                            focusedBorderColor: Colors.blue.shade800,
                            showFieldAsBox: true,
                            onCodeChanged: (String code) {
                              _controller2FA.text = code;
                            },
                            onSubmit: (String code) {
                              _controller2FA.text = code;
                              verify2FA();
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Enter the 6-digit code from your authenticator app',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Error Message
                        if (errorMessage!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: GoogleFonts.poppins(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        if (errorMessage!.isNotEmpty) const SizedBox(height: 20),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : (show2FAField ? verify2FA : (isLogin ? signInWithEmailAndPassword : createUserWithEmailAndPassword)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    show2FAField 
                                        ? 'Verify 2FA'
                                        : (isLogin ? 'Sign In' : 'Create Account'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Forgot Password (only for login)
                        if (isLogin && !show2FAField)
                          TextButton(
                            onPressed: forgotPassword,
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.poppins(
                                color: Colors.blue.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        
                        // Toggle Mode
                        if (!show2FAField)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLogin ? "Don't have an account? " : "Already have an account? ",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: _toggleMode,
                                child: Text(
                                  isLogin ? 'Sign Up' : 'Sign In',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Additional Options
                  if (!show2FAField) ...[
                    Center(
                      child: Text(
                        'Or continue with',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Social Login Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement Google Sign In
                            },
                            icon: Image.asset(
                              'assets/icons/google.png',
                              height: 20,
                              errorBuilder: (context, error, stackTrace) => 
                                  Icon(Icons.g_mobiledata, color: Colors.red.shade600),
                            ),
                            label: Text(
                              'Google',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement Facebook Sign In
                            },
                            icon: Icon(Icons.facebook, color: Colors.blue.shade700),
                            label: Text(
                              'Facebook',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
