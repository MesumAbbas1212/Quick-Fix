import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/worker_content.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/worker/certifications_screen.dart';
class MockProfiles extends Mock implements ProfileService {}
void main() {
  test('credential year/title/issuer validation is explicit and display is not verification', () {
    expect(const WorkerCertificate(id: '', title: 'Trade course', issuer: 'Institute', year: 1969).valid(2026), isFalse);
    expect(const WorkerCertificate(id: '', title: 'Trade course', issuer: 'Institute', year: 2027).valid(2026), isFalse);
    expect(const WorkerCertificate(id: '', title: 'Trade course', issuer: 'Institute', year: 2026).valid(2026), isTrue);
  });
  testWidgets('error retries to an actionable owner empty state', (tester) async {
    final profiles = MockProfiles(); when(() => profiles.watchCertificates('w')).thenAnswer((_) => Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: CertificationsScreen(workerId: 'w', profileService: profiles))); await tester.pumpAndSettle();
    when(() => profiles.watchCertificates('w')).thenAnswer((_) => Stream.value([])); await tester.tap(find.text('Retry')); await tester.pumpAndSettle(); expect(find.text('No certifications listed'), findsOneWidget); expect(find.byKey(const Key('certificate-add')), findsOneWidget);
  });
  testWidgets('client mode labels credentials self-declared and hides mutation', (tester) async {
    final profiles = MockProfiles(); when(() => profiles.watchCertificates('w')).thenAnswer((_) => Stream.value([const WorkerCertificate(id: 'a', title: 'سند', issuer: 'ادارہ', year: 2026)]));
    await tester.pumpWidget(MaterialApp(home: CertificationsScreen(workerId: 'w', readOnly: true, profileService: profiles))); await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('سند')).textDirection, TextDirection.rtl); expect(find.text('2026 • Self-declared'), findsOneWidget); expect(find.byKey(const Key('certificate-add')), findsNothing); expect(find.byKey(const Key('certificate-remove-a')), findsNothing);
  });
}
