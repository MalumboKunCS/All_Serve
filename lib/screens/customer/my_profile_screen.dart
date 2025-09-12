import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('My Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user?.name ?? '-'}', style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Email: ${user?.email ?? '-'}', style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await auth.signOut();
              },
              style: AppTheme.primaryButtonStyle,
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}



