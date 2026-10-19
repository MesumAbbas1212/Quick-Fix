import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/support_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/views/settings/help_centre_screen.dart';
class MockLauncher extends Mock implements UrlLauncher {}
void main() {
  test('mailto uses configured contact only and safely encodes the query', () async {
    final launcher = MockLauncher(); String? opened;
    when(() => launcher.open(any())).thenAnswer((call) async { opened = call.positionalArguments.first as String; return true; });
    final service = SupportService(supportEmail: 'help@example.com', urlLauncher: launcher);
    expect(await service.contact(), isTrue); final uri = Uri.parse(opened!); expect(uri.scheme, 'mailto'); expect(uri.path, 'help@example.com'); expect(uri.queryParameters['subject'], 'QuickFix support');
    expect(SupportService(supportEmail: '').isConfigured, isFalse); await expectLater(SupportService(supportEmail: 'not an email').contact(), throwsStateError);
  });
  test('copy awaits an injectable clipboard without claiming success first', () async {
    String? copied; final service = SupportService(supportEmail: 'help@example.com', copyContact: (value) async { copied = value; });
    await service.copyContact(); expect(copied, 'help@example.com');
  });
  testWidgets('no-match search has a working reset and no invented contact', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HelpCentreScreen(supportService: SupportService(supportEmail: ''))));
    await tester.enterText(find.byKey(const Key('help-search')), 'xyz-no-topic'); await tester.pump(); expect(find.text('No matching help articles'), findsOneWidget);
    await tester.tap(find.byKey(const Key('help-clear-search'))); await tester.pump(); expect(find.text('How do I post a job?'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Support email not configured'), 400); expect(tester.widget<ListTile>(find.byKey(const Key('help-contact-support'))).onTap, isNull);
  });
  testWidgets('FAQ expands the real simulated-payment explanation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpCentreScreen())); await tester.ensureVisible(find.text('Are payments and withdrawals real?'));
    await tester.tap(find.text('Are payments and withdrawals real?')); await tester.pumpAndSettle(); expect(find.textContaining('No card is charged'), findsOneWidget);
  });
}
