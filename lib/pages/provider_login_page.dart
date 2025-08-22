import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/pages/provider_registration_page.dart';

class ProviderLoginPage extends StatefulWidget {
  const ProviderLoginPage({super.key});

  @override
  State<ProviderLoginPage> createState() => _ProviderLoginPageState();
}

class _ProviderLoginPageState extends State<ProviderLoginPage> {
  String? errorMessage = '';
  bool isLogin = true;

  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  @override
  void dispose() {
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    super.dispose();
  }

  Future<void> signInWithEmailAndPassword() async {
    try {
      await Auth().signInWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    try {
      await Auth().createUserWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
      
      // Navigate to provider registration for new users
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProviderRegistrationPage(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    }
  }

  Widget _title() => const Text(
        'Provider Portal',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      );

  Widget _entryField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(
          obscure ? Icons.lock : Icons.email,
        ),
      ),
    );
  }

  Widget _errorMessage() => errorMessage == ''
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        );

  Widget _submitButton() => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: isLogin ? signInWithEmailAndPassword : createUserWithEmailAndPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isLogin ? 'Sign In' : 'Create Account',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );

  Widget _loginOrRegisterButton() => TextButton(
        onPressed: () => setState(() => isLogin = !isLogin),
        child: Text(
          isLogin 
              ? 'New provider? Create account' 
              : 'Already have an account? Sign in',
          style: const TextStyle(color: Colors.blue),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business,
                        size: 64,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(height: 16),
                      _title(),
                      const SizedBox(height: 8),
                      Text(
                        isLogin 
                            ? 'Sign in to manage your services'
                            : 'Join our network of service providers',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _entryField('Email', _controllerEmail),
                      const SizedBox(height: 16),
                      _entryField('Password', _controllerPassword, obscure: true),
                      const SizedBox(height: 16),
                      _errorMessage(),
                      const SizedBox(height: 24),
                      _submitButton(),
                      const SizedBox(height: 16),
                      _loginOrRegisterButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
