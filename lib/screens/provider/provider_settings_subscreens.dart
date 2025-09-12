import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProviderSecurityScreen extends StatelessWidget {
  const ProviderSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('Security Settings'), backgroundColor: AppTheme.surfaceDark),
      body: const Center(child: Text('Security settings coming soon', style: TextStyle(color: Colors.white))),
    );
  }
}

class ProviderNotificationSettingsScreen extends StatelessWidget {
  const ProviderNotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('Notification Settings'), backgroundColor: AppTheme.surfaceDark),
      body: const Center(child: Text('Notification settings coming soon', style: TextStyle(color: Colors.white))),
    );
  }
}

class ProviderHelpScreen extends StatelessWidget {
  const ProviderHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('Help & Support'), backgroundColor: AppTheme.surfaceDark),
      body: const Center(child: Text('Help & support coming soon', style: TextStyle(color: Colors.white))),
    );
  }
}

class ProviderTermsScreen extends StatelessWidget {
  const ProviderTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('Terms & Privacy'), backgroundColor: AppTheme.surfaceDark),
      body: const Center(child: Text('Terms & privacy coming soon', style: TextStyle(color: Colors.white))),
    );
  }
}



