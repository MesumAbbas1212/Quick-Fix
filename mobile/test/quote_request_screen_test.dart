// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/location_selection.dart';
import 'package:quickfix/models/quote_inquiry.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/quote_service.dart';
import 'package:quickfix/views/jobs/quote_request_screen.dart';
class MockQuotes extends Mock implements QuoteService {}
class MockDB extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
final client = UserModel(uid: 'c', email: '', fullName: 'Client', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  test('quote IDs are stable/unambiguous and public area is coarsened without changing exact pin', () {
    expect(QuoteService.quoteId('a_b', 'c'), isNot(QuoteService.quoteId('a', 'b_c'))); expect(QuoteService.quoteId('r', 'w'), QuoteService.quoteId('r', 'w'));
    const exact = GeoPoint(33.12345, 72.98765); expect(QuoteService.approximate(exact), const GeoPoint(33.12, 72.99)); expect(exact.latitude, 33.12345);
  });
  test('default-off server flag prevents creates before any inquiry/worker writes', () async {
    final db = MockDB(); final config = MockCollection(); final ref = MockRef(); final snapshot = MockSnapshot();
    when(() => db.collection('config')).thenReturn(config); when(() => config.doc('features')).thenReturn(ref); when(() => ref.get(const GetOptions(source: Source.server))).thenAnswer((_) async => snapshot); when(() => snapshot.data()).thenReturn({'quotesEnabled': false});
    final service = QuoteService(firestore: db);
    await expectLater(service.create(clientId: 'c', category: JobCategory.plumbing, description: 'Meaningful description of the work needed', images: [], location: const LocationSelection(address: 'Attock', location: GeoPoint(33, 72)), radiusKm: 10, expectedRecipients: ['w']), throwsStateError);
    verifyNever(() => db.collection('quoteRequests')); verifyNever(() => db.collection('workers'));
  });
  testWidgets('gated page has no pretend invitation/booking form', (tester) async {
    final quotes = MockQuotes(); when(() => quotes.isEnabled()).thenAnswer((_) async => false);
    await tester.pumpWidget(MaterialApp(home: QuoteRequestScreen(user: client, quoteService: quotes))); await tester.pumpAndSettle();
    expect(find.text('Quote requests are not enabled'), findsOneWidget); expect(find.byKey(const Key('quote-description')), findsNothing); verifyNever(() => quotes.newInquiryId());
  });
  testWidgets('owner sees a real pending/answered request and no invented replies', (tester) async {
    final quotes = MockQuotes(); when(() => quotes.isEnabled()).thenAnswer((_) async => true);
    when(() => quotes.watchRequest('r')).thenAnswer((_) => Stream.value(const QuoteInquiry(id: 'r', clientId: 'c', description: 'مرمت کی درخواست', status: 'open', category: JobCategory.plumbing, recipientIds: ['w'])));
    when(() => quotes.watchQuotes('r', 'c', owner: true)).thenAnswer((_) => Stream.value([]));
    await tester.pumpWidget(MaterialApp(home: QuoteRequestScreen(user: client, requestId: 'r', quoteService: quotes))); await tester.pumpAndSettle();
    expect(find.text('Waiting for worker replies'), findsOneWidget); expect(tester.widget<Text>(find.text('مرمت کی درخواست')).textDirection, TextDirection.rtl); expect(find.byKey(const Key('quote-reply-submit')), findsNothing);
  });
}
