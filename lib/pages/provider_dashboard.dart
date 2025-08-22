import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:all_server/auth.dart';
import 'package:all_server/pages/provider_login_page.dart';
import 'package:all_server/pages/provider_home_page.dart';

class ProviderDashboard extends StatelessWidget {
  const ProviderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const ProviderHomePage();
        } else {
          return const ProviderLoginPage();
        }
      },
    );
  }
}

