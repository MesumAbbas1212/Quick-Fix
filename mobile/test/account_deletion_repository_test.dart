// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/services/account_deletion_repository.dart';
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockDocument extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockQueryDocument extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockMetadata extends Mock implements SnapshotMetadata {}
class MockBatch extends Mock implements WriteBatch {}
class MockTransaction extends Mock implements Transaction {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
void main() {
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  late MockFirestore firestore; late MockCollection collection; late MockQuery query; late MockSnapshot snapshot; late MockMetadata metadata;
  setUp(() {
    firestore = MockFirestore(); collection = MockCollection(); query = MockQuery(); snapshot = MockSnapshot(); metadata = MockMetadata();
    when(() => firestore.collection(any())).thenReturn(collection);
    when(() => collection.where(any(), isEqualTo: any(named: 'isEqualTo'))).thenReturn(query);
    when(() => query.where('status', whereIn: ['assigned', 'inProgress'])).thenReturn(query);
    when(() => query.limit(1)).thenReturn(query);
    when(() => query.get(const GetOptions(source: Source.server))).thenAnswer((_) async => snapshot);
    when(() => snapshot.docs).thenReturn([]); when(() => snapshot.metadata).thenReturn(metadata);
    when(() => metadata.isFromCache).thenReturn(false); when(() => metadata.hasPendingWrites).thenReturn(false);
  });
  test('active-work guard checks both ownership roles using server-confirmed reads', () async {
    expect(await AccountDeletionRepository(firestore: firestore).hasActiveJobs('u'), isFalse);
    verify(() => collection.where('userId', isEqualTo: 'u')).called(1); verify(() => collection.where('workerId', isEqualTo: 'u')).called(1);
    verify(() => query.get(const GetOptions(source: Source.server))).called(2);
  });
  test('a cached or unacknowledged snapshot is not trusted as an empty preflight', () async {
    when(() => metadata.isFromCache).thenReturn(true);
    await expectLater(AccountDeletionRepository(firestore: firestore).hasActiveJobs('u'), throwsA(isA<AccountDeletionException>()));
  });
  test('an active job blocks immediately instead of starting content cleanup', () async {
    when(() => snapshot.docs).thenReturn([MockQueryDocument()]);
    expect(await AccountDeletionRepository(firestore: firestore).hasActiveJobs('u'), isTrue);
    verify(() => query.get(const GetOptions(source: Source.server))).called(1);
  });
  test('private proof, worker and user deletes share an acknowledged batch before Auth', () async {
    final batch = MockBatch(); final document = MockDocument();
    when(() => firestore.waitForPendingWrites()).thenAnswer((_) async {}); when(() => firestore.batch()).thenReturn(batch);
    when(() => collection.doc('u')).thenReturn(document); when(() => batch.commit()).thenAnswer((_) async {});
    await AccountDeletionRepository(firestore: firestore).deleteProfiles('u');
    verify(() => firestore.collection('workerVerifications')).called(1); verify(() => firestore.collection('workers')).called(1); verify(() => firestore.collection('users')).called(1);
    verify(() => batch.delete(document)).called(3); verify(() => batch.update(document, any())).called(1); verify(() => batch.commit()).called(1);
  });
  test('begin writes only a private checking marker with a server timestamp', () async {
    final transaction = MockTransaction(); final document = MockDocument(); final data = MockDocumentSnapshot();
    when(() => collection.doc('u')).thenReturn(document); when(() => transaction.get(document)).thenAnswer((_) async => data); when(() => data.exists).thenReturn(false);
    when(() => transaction.set<Map<String, dynamic>>(document, any(), any())).thenReturn(transaction);
    when(() => firestore.runTransaction<void>(any())).thenAnswer((invocation) async { await (invocation.positionalArguments.first as Future<void> Function(Transaction))(transaction); });
    await AccountDeletionRepository(firestore: firestore).begin('u');
    final fields = verify(() => transaction.set<Map<String, dynamic>>(document, captureAny(), any())).captured.single as Map<String, dynamic>;
    expect(fields.keys.toSet(), {'state', 'startedAt'}); expect(fields['state'], 'checking'); expect(fields['startedAt'], isA<FieldValue>());
  });
  test('expired cleanup pass stops before another server read and asks to resume', () async {
    var clock = DateTime(2026); final transaction = MockTransaction(); final document = MockDocument(); final data = MockDocumentSnapshot();
    when(() => collection.doc('u')).thenReturn(document); when(() => transaction.get(document)).thenAnswer((_) async => data); when(() => data.exists).thenReturn(true);
    when(() => firestore.runTransaction<void>(any())).thenAnswer((invocation) async { await (invocation.positionalArguments.first as Future<void> Function(Transaction))(transaction); });
    final repository = AccountDeletionRepository(firestore: firestore, now: () => clock); await repository.begin('u'); clock = clock.add(const Duration(minutes: 3));
    await expectLater(repository.cleanup('u'), throwsA(isA<AccountDeletionException>().having((error) => error.message, 'message', contains('another cleanup pass'))));
    verifyNever(() => firestore.waitForPendingWrites());
  });

}
