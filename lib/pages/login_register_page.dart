import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/pages/profile_setup_page.dart';
import 'package:all_server/services/profile_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? errorMessage = '';
  bool isLogin = true;  

  final TextEditingController _controllerEmail    = TextEditingController(); 
  final TextEditingController _controllerPassword = TextEditingController();
  final ProfileService _profileService = ProfileService();

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
      
      // Navigate to profile setup for new users
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileSetupPage(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    }
  }

  Widget _title() => const Text('Firebase Auth');

  Widget _entryField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _errorMessage() =>
      Text(errorMessage == '' ? '' : 'Hmm? $errorMessage');

  Widget _submitButton() => ElevatedButton(
        onPressed:
            isLogin ? signInWithEmailAndPassword : createUserWithEmailAndPassword,
        child: Text(isLogin ? 'Login' : 'Register'),
      );

  Widget _loginOrRegisterButton() => TextButton(
        onPressed: () => setState(() => isLogin = !isLogin),
        child: Text(isLogin ? 'Register instead' : 'Login instead'),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: _title()),                
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _entryField('Email', _controllerEmail),
            _entryField('Password', _controllerPassword, obscure: true),
            _errorMessage(),
            _submitButton(),
            _loginOrRegisterButton(),
          ],
        ),
      ),
    );
  }
}
