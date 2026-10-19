// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/quote_service.dart';
class MockDB extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
class EnabledQuotes extends QuoteService {
  EnabledQuotes(FirebaseFirestore db) : super(firestore: db);
  @override Future<bool> isEnabled() async => true;
}
void main() {
  late MockDB db; late MockRef request, reply, pin; late MockSnapshot inquiry, quote, location; late MockTransaction transaction; late EnabledQuotes service;
  setUpAll(() { registerFallbackValue((Transaction _) async {}); registerFallbackValue((Transaction _) async => 'job'); });
  setUp(() {
    db = MockDB(); request = MockRef(); reply = MockRef(); pin = MockRef(); inquiry = MockSnapshot(); quote = MockSnapshot(); location = MockSnapshot(); transaction = MockTransaction();
    final requests = MockCollection(); final quotes = MockCollection(); final private = MockCollection(); final jobs = MockCollection();
    when(() => db.collection('quoteRequests')).thenReturn(requests); when(() => db.collection('quotes')).thenReturn(quotes); when(() => db.collection('jobs')).thenReturn(jobs);
    when(() => requests.doc('r')).thenReturn(request); when(() => quotes.doc(any())).thenReturn(reply); when(() => jobs.doc()).thenReturn(MockRef());
    when(() => request.collection('private')).thenReturn(private); when(() => private.doc('location')).thenReturn(pin);
    when(() => transaction.get(request)).thenAnswer((_) async => inquiry); when(() => transaction.get(reply)).thenAnswer((_) async => quote); when(() => transaction.get(pin)).thenAnswer((_) async => location);
    when(() => quote.exists).thenReturn(true); when(() => location.data()).thenReturn(null);
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async { await (call.positionalArguments.first as Future<void> Function(Transaction))(transaction); });
    when(() => db.runTransaction<String>(any())).thenAnswer((call) async => await (call.positionalArguments.first as Future<String> Function(Transaction))(transaction));
    service = EnabledQuotes(db);
  });
  test('a retry of an existing reply does not create another quote/notification', () async {
    when(() => inquiry.data()).thenReturn({'status': 'open', 'recipientIds': ['w'], 'clientId': 'c'});
    await service.reply(requestId: 'r', workerId: 'w', amount: 123, message: 'Scope included'); verifyNever(() => transaction.set<Map<String, dynamic>>(reply, any(), any()));
  });
  test('uninvited workers cannot reply even through the service API', () async {
    when(() => inquiry.data()).thenReturn({'status': 'open', 'recipientIds': ['other'], 'clientId': 'c'});
    await expectLater(service.reply(requestId: 'r', workerId: 'w', amount: 123, message: 'Scope included'), throwsStateError);
    verifyNever(() => transaction.set<Map<String, dynamic>>(reply, any(), any()));
  });
  test('acknowledged accept retry returns the original job instead of double booking', () async {
    when(() => inquiry.data()).thenReturn({'status': 'accepted', 'clientId': 'c', 'acceptedQuoteId': 'q', 'jobId': 'original-job'});
    when(() => quote.data()).thenReturn({'requestId': 'r', 'clientId': 'c'});
    final id = await service.accept(requestId: 'r', quoteId: 'q', clientId: 'c', title: 'Work', date: DateTime.now().add(const Duration(days: 2)));
    expect(id, 'original-job'); verifyNever(() => transaction.update(request, any()));
  });
}
