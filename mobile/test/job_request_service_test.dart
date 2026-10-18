// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockQueryDoc extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}

void main() {
  group('JobRequestService', () {
    late MockFirestore firestore;
    late MockCollection requests;
    late MockCollection jobs;
    late MockQuery query;
    late MockQuerySnapshot snapshot;
    late MockDoc selectedRef;
    late MockDoc otherRef;
    late MockDoc jobRef;
    late MockSnapshot jobDoc;
    late MockSnapshot selectedDoc;
    late MockSnapshot otherDoc;
    late MockTransaction transaction;
    late JobRequestService service;
    late JobService jobService;

    setUpAll(() {
      registerFallbackValue((Transaction _) async {});
    });

    setUp(() {
      firestore = MockFirestore();
      requests = MockCollection();
      jobs = MockCollection();
      query = MockQuery();
      snapshot = MockQuerySnapshot();
      selectedRef = MockDoc();
      otherRef = MockDoc();
      jobRef = MockDoc();
      jobDoc = MockSnapshot();
      selectedDoc = MockSnapshot();
      otherDoc = MockSnapshot();
      transaction = MockTransaction();
      service = JobRequestService(firestore: firestore);
      jobService = JobService(firestore: firestore);
      when(() => firestore.collection('jobRequests')).thenReturn(requests);
      when(() => firestore.collection('jobs')).thenReturn(jobs);
      when(() => requests.doc('r1')).thenReturn(selectedRef);
      when(() => requests.doc('r2')).thenReturn(otherRef);
      when(() => jobs.doc('j1')).thenReturn(jobRef);
      when(() => selectedRef.id).thenReturn('r1');
      when(() => otherRef.id).thenReturn('r2');
      when(() => jobRef.id).thenReturn('j1');
      when(() => selectedRef.update(any())).thenAnswer((_) async {});
    });

    void stubTransaction({
      String jobStatus = 'open',
      String owner = 'me',
      String? assignedWorker,
      String selectedStatus = 'pending',
      String selectedOwner = 'me',
      String otherStatus = 'pending',
    }) {
      final selectedQueryDoc = MockQueryDoc();
      final otherQueryDoc = MockQueryDoc();
      when(() => selectedQueryDoc.id).thenReturn('r1');
      when(() => selectedQueryDoc.reference).thenReturn(selectedRef);
      when(() => otherQueryDoc.id).thenReturn('r2');
      when(() => otherQueryDoc.reference).thenReturn(otherRef);
      when(() => requests.where('jobId', isEqualTo: 'j1')).thenReturn(query);
      when(() => query.get()).thenAnswer((_) async => snapshot);
      when(() => snapshot.docs).thenReturn([selectedQueryDoc, otherQueryDoc]);
      when(() => jobDoc.data()).thenReturn({
        'userId': owner, 'status': jobStatus, 'workerId': assignedWorker,
      });
      when(() => selectedDoc.data()).thenReturn({
        'jobId': 'j1', 'userId': selectedOwner, 'workerId': 'w1', 'status': selectedStatus,
      });
      when(() => otherDoc.data()).thenReturn({
        'jobId': 'j1', 'userId': 'me', 'workerId': 'w2', 'status': otherStatus,
      });
      when(() => transaction.get(jobRef)).thenAnswer((_) async => jobDoc);
      when(() => transaction.get(selectedRef)).thenAnswer((_) async => selectedDoc);
      when(() => transaction.get(otherRef)).thenAnswer((_) async => otherDoc);
      when(() => transaction.update(jobRef, any())).thenReturn(transaction);
      when(() => transaction.update(selectedRef, any())).thenReturn(transaction);
      when(() => transaction.update(otherRef, any())).thenReturn(transaction);
      when(() => firestore.runTransaction<void>(any())).thenAnswer((invocation) async {
        final handler = invocation.positionalArguments.single
            as Future<void> Function(Transaction);
        await handler(transaction);
      });
    }

    Future<void> accept() => service.acceptApplicant(
      jobId: 'j1', requestId: 'r1', ownerId: 'me', jobService: jobService,
    );

    test('watchPendingCountForJob counts query documents, not document references', () async {
      when(() => requests.where('jobId', isEqualTo: 'j1')).thenReturn(query);
      when(() => query.where('status', isEqualTo: 'pending')).thenReturn(query);
      when(() => query.snapshots()).thenAnswer((_) => Stream.value(snapshot));
      when(() => snapshot.docs).thenReturn([MockQueryDoc(), MockQueryDoc()]);
      expect(await service.watchPendingCountForJob('j1').first, 2);
      verify(() => requests.where('jobId', isEqualTo: 'j1')).called(1);
      verify(() => query.where('status', isEqualTo: 'pending')).called(1);
    });

    test('watchPendingCountForJob yields zero with no applicants', () async {
      when(() => requests.where('jobId', isEqualTo: 'j1')).thenReturn(query);
      when(() => query.where('status', isEqualTo: 'pending')).thenReturn(query);
      when(() => query.snapshots()).thenAnswer((_) => Stream.value(snapshot));
      when(() => snapshot.docs).thenReturn([]);
      expect(await service.watchPendingCountForJob('j1').first, 0);
    });

    test('respondToRequest preserves the existing update API and timestamp', () async {
      await service.respondToRequest(requestId: 'r1', status: JobRequestStatus.accepted);
      final written = verify(() => selectedRef.update(captureAny()))
          .captured.single as Map<String, dynamic>;
      expect(written['status'], 'accepted');
      expect(written['respondedAt'], isA<Timestamp>());
    });

    test('accept assigns the job, accepts one request and declines the rest in one transaction', () async {
      stubTransaction();
      await accept();
      final jobUpdates = verify(() => transaction.update(jobRef, captureAny()))
          .captured.single as Map<String, dynamic>;
      final selectedUpdates = verify(() => transaction.update(selectedRef, captureAny()))
          .captured.single as Map<String, dynamic>;
      final otherUpdates = verify(() => transaction.update(otherRef, captureAny()))
          .captured.single as Map<String, dynamic>;
      expect(jobUpdates['workerId'], 'w1');
      expect(jobUpdates['status'], 'assigned');
      expect(jobUpdates['assignedAt'], isA<Timestamp>());
      expect(jobUpdates['updatedAt'], isA<Timestamp>());
      expect(selectedUpdates['status'], 'accepted');
      expect(otherUpdates['status'], 'declined');
      expect(selectedUpdates['respondedAt'], isA<Timestamp>());
      expect(otherUpdates['respondedAt'], isA<Timestamp>());
      verifyNever(() => jobRef.update(any()));
      verifyNever(() => selectedRef.update(any()));
      verifyNever(() => otherRef.update(any()));
    });

    test('all transaction reads happen before any transaction write', () async {
      stubTransaction();
      await accept();
      verifyInOrder([
        () => transaction.get(jobRef),
        () => transaction.get(selectedRef),
        () => transaction.get(otherRef),
        () => transaction.update(jobRef, any()),
        () => transaction.update(selectedRef, any()),
        () => transaction.update(otherRef, any()),
      ]);
    });

    test('a job already assigned elsewhere cannot be overwritten or decline candidates', () async {
      stubTransaction(jobStatus: 'assigned', assignedWorker: 'another-worker');
      await expectLater(accept(), throwsStateError);
      verifyNever(() => transaction.update(jobRef, any()));
      verifyNever(() => transaction.update(selectedRef, any()));
      verifyNever(() => transaction.update(otherRef, any()));
    });

    test('only the job owner can select an applicant', () async {
      stubTransaction(owner: 'someone-else');
      await expectLater(accept(), throwsStateError);
      verifyNever(() => transaction.update(jobRef, any()));
      verifyNever(() => transaction.update(selectedRef, any()));
      verifyNever(() => transaction.update(otherRef, any()));
    });

    test('a request from a different owner cannot be accepted', () async {
      stubTransaction(selectedOwner: 'someone-else');
      await expectLater(accept(), throwsStateError);
      verifyNever(() => transaction.update(jobRef, any()));
    });

    test('a stale non-pending applicant cannot be accepted', () async {
      stubTransaction(selectedStatus: 'declined');
      await expectLater(accept(), throwsStateError);
      verifyNever(() => transaction.update(jobRef, any()));
      verifyNever(() => transaction.update(otherRef, any()));
    });

    test('already-declined requests are not rewritten', () async {
      stubTransaction(otherStatus: 'declined');
      await accept();
      verify(() => transaction.update(jobRef, any())).called(1);
      verify(() => transaction.update(selectedRef, any())).called(1);
      verifyNever(() => transaction.update(otherRef, any()));
    });

    test('an acknowledged retry of the same assignment is idempotent', () async {
      stubTransaction(jobStatus: 'assigned', assignedWorker: 'w1', selectedStatus: 'accepted');
      await accept();
      verifyNever(() => transaction.update(jobRef, any()));
      verifyNever(() => transaction.update(selectedRef, any()));
      verifyNever(() => transaction.update(otherRef, any()));
    });
  });
}
