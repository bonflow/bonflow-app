import 'package:bonflow_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on the login screen and navigates to the tables', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BonflowApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
