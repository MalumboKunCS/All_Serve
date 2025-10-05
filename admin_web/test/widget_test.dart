import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/main.dart';
import 'package:shared/shared.dart' as shared;

void main() {
  testWidgets('Admin app smoke test', (WidgetTester tester) async {
    // Create a mock auth service
    final authService = shared.AuthService();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(AdminWebApp(authService: authService));

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}