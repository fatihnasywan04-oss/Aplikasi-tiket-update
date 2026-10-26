import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_ticketers/screens/auth/login_page.dart';

void main() {
  testWidgets('Login page dapat ditampilkan', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Event Ticketers'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
