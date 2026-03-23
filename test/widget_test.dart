// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple widget test', (WidgetTester tester) async {
    // Build a simple test widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Test App'))),
      ),
    );

    // Verify that our test widget is displayed
    expect(find.text('Test App'), findsOneWidget);
  });
}
