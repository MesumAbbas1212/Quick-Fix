import 'helpers/visible.dart' as test_viewport;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/views/settings/legal_screen.dart';
import 'package:quickfix/views/settings/settings_screen.dart';
void main() {
  testWidgets('Terms and Privacy switch between numbered, scrollable prototype clauses', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    expect(find.text('1. About this demo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('legal-privacy-tab'))); await tester.pumpAndSettle();
    expect(find.text('1. Account and profile data'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('6. Google Cloud Translation and summaries'), 500, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Google Cloud Translation.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('9. Limits of erasure and your choices'), 500, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('does not remotely wipe'), findsOneWidget);
  });
  testWidgets('Privacy can open directly and discloses one-shot/device-local behavior', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen(initialTab: 1)));
    await tester.scrollUntilVisible(find.text('4. One-shot location, not tracking'), 400, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('There is no background location subscription'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('5. Device-local images and caches'), 400, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Firebase Storage is not used'), findsOneWidget);
  });
  testWidgets('Settings routes its Privacy row to the correct tab', (tester) async {
    final user = UserModel(uid: 'u', fullName: 'Client', email: 'c@example.com', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(user: user)));
    await test_viewport.reveal(tester, find.byKey(const Key('settings-privacy'))); await tester.tap(find.byKey(const Key('settings-privacy'))); await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget); expect(find.text('1. Account and profile data'), findsOneWidget);
  });
  testWidgets('large text at narrow width scrolls rather than overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 600); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!), home: const LegalScreen()));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -400)); await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
  });
}
