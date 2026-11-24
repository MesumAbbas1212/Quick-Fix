// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/job_service.dart';

class _Db extends Mock implements FirebaseFirestore {}

class _Jobs extends Mock implements CollectionReference<Map<String, dynamic>> {}

class _Ref extends Mock implements DocumentReference<Map<String, dynamic>> {}

class _Snap extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

class _Tx extends Mock implements Transaction {}

/// Client cancellation of an open job (item 1). Cancelling keeps the document;
/// the transaction refuses anything that is not the owner's open job.
void main() {
  late _Db db;
  late _Jobs jobs;
  late _Ref ref;
  late _Snap snap;
  late _Tx tx;
  late JobService service;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    db = _Db();
    jobs = _Jobs();
    ref = _Ref();
    snap = _Snap();
    tx = _Tx();
    service = JobService(firestore: db);
    when(() => db.collection('jobs')).thenReturn(jobs);
    when(() => jobs.doc('j1')).thenReturn(ref);
    when(() => tx.get(ref)).thenAnswer((_) async => snap);
    when(() => tx.update(ref, any())).thenReturn(tx);
    when(() => snap.exists).thenReturn(true);
    when(() => db.runTransaction<void>(any())).thenAnswer((invocation) async {
      await (invocation.positionalArguments.single as Future<void> Function(Transaction))(tx);
    });
  });

  void status(String value, {String owner = 'me'}) {
    when(() => snap.data()).thenReturn({
      'status': value,
      'userId': owner,
      'workerId': null,
    });
  }

  test('an open job is cancelled, never deleted', () async {
    status('open');

    await service.cancelOpenJob('j1', ownerId: 'me');

    final data =
        verify(() => tx.update(ref, captureAny())).captured.single as Map;
    expect(data['status'], 'cancelled');
    expect(data['cancelReason'], 'Cancelled by client');
    expect(data['cancelledAt'], isNotNull);
    expect(data['updatedAt'], isA<Timestamp>());
    verifyNever(() => ref.delete());
  });

  test('a custom reason is preserved', () async {
    status('open');

    await service.cancelOpenJob('j1', ownerId: 'me', reason: 'Found someone else');

    final data =
        verify(() => tx.update(ref, captureAny())).captured.single as Map;
    expect(data['cancelReason'], 'Found someone else');
  });

  test('another account cannot cancel the job', () async {
    status('open', owner: 'someone-else');

    await expectLater(
      service.cancelOpenJob('j1', ownerId: 'me'),
      throwsStateError,
    );
    verifyNever(() => tx.update(any(), any()));
  });

  test('an assigned job is not cancellable from this shortcut', () async {
    status('assigned');

    await expectLater(
      service.cancelOpenJob('j1', ownerId: 'me'),
      throwsStateError,
    );
    verifyNever(() => tx.update(any(), any()));
  });

  test('a retry after an acknowledged cancel writes nothing more', () async {
    status('cancelled');

    await service.cancelOpenJob('j1', ownerId: 'me');

    verifyNever(() => tx.update(any(), any()));
  });
}
