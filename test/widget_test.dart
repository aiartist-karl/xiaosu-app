// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility class that the test package provides. For example, you can send
// tap and scroll gestures. You can also use WidgetTester to find child widgets
// in the widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaosucore/main.dart';

void main() {
  testWidgets('App smoke test - app renders without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app renders without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App has a Scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify the app has a Scaffold
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('App title is correct', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify the app title contains expected text
    expect(find.text('酥心'), findsOneWidget);
  });
}
