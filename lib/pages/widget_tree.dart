import 'package:all_server/auth.dart';
import 'package:flutter/material.dart';
import 'package:all_server/pages/home_page.dart';
import 'package:all_server/pages/enhanced_login_page.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const HomePage();
        } else {
          return const EnhancedLoginPage();
        }
      },
    );
  }
}
