import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiaosu/app.dart';

void main() {
  testWidgets('App smoke test - app renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: XiaoSuApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App has a Scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: XiaoSuApp()));
    expect(find.byType(Scaffold), findsWidgets);
  });
}
