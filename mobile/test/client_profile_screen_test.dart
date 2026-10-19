import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/client_activity.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/client_activity_service.dart';
import 'package:quickfix/views/worker/client_profile_screen.dart';
class MockActivity extends Mock implements ClientActivityService {}
final customer = UserModel(uid: 'c', email: 'private@example.com', fullName: 'سارہ', phone: 'private-phone', role: UserRole.user, createdAt: DateTime(2020), updatedAt: DateTime(2026));
JobModel privateJob() => JobModel(id: 'j', userId: 'c', title: 'House 123 exact street', description: 'Sensitive details', category: JobCategory.plumbing, address: 'Exact secret address', location: const GeoPoint(33.12345, 72.54321), budgetMin: 1, budgetMax: 2, preferredDate: DateTime(2026), createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  test('client activity projection never exposes title/address/coordinates/contact fields', () {
    final data = ClientActivityService.project(customer, [privateJob()], []); expect(data.posted, 1); expect(data.jobs.single.category, JobCategory.plumbing); expect(data.averageGiven, isNull);
    expect(data.completed, 0); expect(data.cancelled, 0);
  });
  testWidgets('public client page is RTL-safe and withholds exact-location/contact fields', (tester) async {
    final service = MockActivity(); when(() => service.watch('c')).thenAnswer((_) => Stream.value(ClientActivityService.project(customer, [privateJob()], [])));
    await tester.pumpWidget(MaterialApp(home: ClientProfileScreen(clientId: 'c', viewerId: 'w', activityService: service))); await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('سارہ')).textDirection, TextDirection.rtl); expect(find.text('House 123 exact street'), findsNothing); expect(find.text('Exact secret address'), findsNothing); expect(find.text('private-phone'), findsNothing); expect(find.text('private@example.com'), findsNothing);
    expect(find.text('Plumbing'), findsOneWidget); expect(find.byKey(const Key('client-profile-report')), findsOneWidget);
  });
  testWidgets('load error retries a missing-client state without fake identity', (tester) async {
    final service = MockActivity(); when(() => service.watch('c')).thenAnswer((_) => Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: ClientProfileScreen(clientId: 'c', viewerId: 'w', activityService: service))); await tester.pumpAndSettle();
    when(() => service.watch('c')).thenAnswer((_) => Stream<ClientActivity?>.value(null)); await tester.tap(find.text('Retry')); await tester.pumpAndSettle(); expect(find.text('Client unavailable'), findsOneWidget); expect(find.byKey(const Key('client-profile-report')), findsNothing);
  });
}
