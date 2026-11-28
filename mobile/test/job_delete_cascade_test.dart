// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/job_service.dart';

class _Db extends Mock implements FirebaseFirestore {}

class _Coll extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _Doc extends Mock implements DocumentReference<Map<String, dynamic>> {}

class _Snap extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

/// Query results carry QueryDocumentSnapshot, not DocumentSnapshot; the two are
/// different types and mixing them is what broke this file.
class _QDocSnap extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _QuerySnap extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _Q extends Mock implements Query<Map<String, dynamic>> {}

class _Batch extends Mock implements WriteBatch {}

/// Fallback instances so any() can match the document-reference parameters of
/// WriteBatch.delete/set, which are declared with different generics.
class _AnyDoc extends Mock implements DocumentReference<Object?> {}

class _DynDoc extends Mock implements DocumentReference<dynamic> {}

/// Records what a mocked batch was asked to do, so the cascade can be asserted
/// from the outside rather than from private state.
class _Recorder {
  final List<List<String>> deleted = [];
  final List<Map<String, dynamic>> sets = [];
  final List<String> setPaths = [];

  int get deleteCount =>
      deleted.fold(0, (total, batch) => total + batch.length);
  bool deleteCalled(String path) =>
      deleted.any((batch) => batch.contains(path));
  Map<String, dynamic> get audit => sets.last;
  String get auditPath => setPaths.last;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_AnyDoc());
    registerFallbackValue(_DynDoc());
    registerFallbackValue(_Doc());
  });

  late _Db db;
  late _Coll jobs;
  late _Coll jobRequests;
  late _Coll notifications;
  late _Coll deletedJobs;
  late _Coll payments;
  late _Coll reviews;
  late _Coll users;
  late _Doc jobRef;
  late _Doc adminRef;
  late _Snap jobSnap;
  late _Snap adminSnap;
  late _Q requestsQuery;
  late _Q notificationsQuery;
  late _QuerySnap requestsSnap;
  late _QuerySnap notificationsSnap;
  late _QuerySnap privateSnap;
  late _Recorder recorder;
  late JobService service;

  /// Every private subcollection read of jobs/j1 returns [privateDocs].
  void stubPrivate(List<QueryDocumentSnapshot<Map<String, dynamic>>> privateDocs) {
    privateSnap = _QuerySnap();
    when(() => privateSnap.docs).thenReturn(privateDocs);
    final privateColl = _Coll();
    when(() => privateColl.get()).thenAnswer((_) async => privateSnap);
    when(() => jobRef.collection('private')).thenReturn(privateColl);
  }

  _Doc docWith(String path) {
    final d = _Doc();
    when(() => d.path).thenReturn(path);
    return d;
  }

  setUp(() {
    recorder = _Recorder();
    db = _Db();
    jobs = _Coll();
    jobRequests = _Coll();
    notifications = _Coll();
    deletedJobs = _Coll();
    payments = _Coll();
    reviews = _Coll();
    users = _Coll();
    jobRef = docWith('jobs/j1');
    adminRef = docWith('users/admin');
    jobSnap = _Snap();
    adminSnap = _Snap();
    requestsQuery = _Q();
    notificationsQuery = _Q();
    requestsSnap = _QuerySnap();
    notificationsSnap = _QuerySnap();

    service = JobService(firestore: db);

    when(() => db.collection('jobs')).thenReturn(jobs);
    when(() => db.collection('jobRequests')).thenReturn(jobRequests);
    when(() => db.collection('notifications')).thenReturn(notifications);
    when(() => db.collection('deletedJobs')).thenReturn(deletedJobs);
    when(() => db.collection('payments')).thenReturn(payments);
    when(() => db.collection('reviews')).thenReturn(reviews);
    when(() => db.collection('users')).thenReturn(users);
    when(() => jobs.doc('j1')).thenReturn(jobRef);
    when(() => users.doc('admin')).thenReturn(adminRef);
    final auditRef = docWith('deletedJobs/j1');
    when(() => deletedJobs.doc('j1')).thenReturn(auditRef);

    when(() => jobSnap.exists).thenReturn(true);
    when(() => jobSnap.data()).thenReturn({
      'userId': 'client',
      'workerId': 'worker',
      'title': 'Leaky kitchen sink',
      'category': 'plumbing',
      'status': 'completed',
      'budgetMin': 1500,
      'budgetMax': 3000,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    when(() => jobRef.get()).thenAnswer((_) async => jobSnap);

    when(() => adminSnap.data()).thenReturn({'role': 'admin'});
    when(() => adminRef.get()).thenAnswer((_) async => adminSnap);

    // 2 applications, each with one private subdocument.
    final requestA = docWith('jobRequests/r1');
    final requestB = docWith('jobRequests/r2');
    final requestASnap = _QDocSnap();
    final requestBSnap = _QDocSnap();
    when(() => requestASnap.reference).thenReturn(requestA);
    when(() => requestBSnap.reference).thenReturn(requestB);
    final emptyColl = _Coll();
    final emptyRequestsSnap = _QuerySnap();
    when(() => emptyRequestsSnap.docs).thenReturn([]);
    when(() => emptyColl.get()).thenAnswer((_) async => emptyRequestsSnap);
    when(() => requestA.collection('private')).thenReturn(emptyColl);
    when(() => requestB.collection('private')).thenReturn(emptyColl);
    when(() => requestsSnap.docs).thenReturn([requestASnap, requestBSnap]);
    when(() => jobRequests.where('jobId', isEqualTo: 'j1'))
        .thenReturn(requestsQuery);
    when(() => requestsQuery.get()).thenAnswer((_) async => requestsSnap);

    // 3 notifications pointing at the job.
    final notificationDocs = [
      docWith('notifications/n0'),
      docWith('notifications/n1'),
      docWith('notifications/n2'),
    ].map((ref) {
      final snap = _QDocSnap();
      when(() => snap.reference).thenReturn(ref);
      return snap;
    }).toList();
    when(() => notificationsSnap.docs).thenReturn(notificationDocs);
    when(() => notifications.where('refId', isEqualTo: 'j1'))
        .thenReturn(notificationsQuery);
    when(() => notificationsQuery.where('type', whereIn: any(named: 'whereIn')))
        .thenReturn(notificationsQuery);
    when(() => notificationsQuery.get())
        .thenAnswer((_) async => notificationsSnap);

    // 1 private document under the job.
    final privateDoc = _QDocSnap();
    // Built before the stub: docWith() itself calls when(), which mocktail
    // rejects while a stub is being recorded.
    final privateRef = docWith('jobs/j1/private/pin');
    when(() => privateDoc.reference).thenReturn(privateRef);
    stubPrivate([privateDoc]);

    // mocktail forbids calling `when` inside a stub response, so the batches are
    // built and stubbed up front and handed out in order.
    final pool = <_Batch>[];
    for (var i = 0; i < 8; i++) {
      recorder.deleted.add([]);
      final batch = _Batch();
      when(() => batch.delete(any())).thenAnswer((invocation) {
        final ref = invocation.positionalArguments.first
            as DocumentReference<Map<String, dynamic>>;
        recorder.deleted[i].add(ref.path);
      });
      when(() => batch.set<Map<String, dynamic>>(any(), any())).thenAnswer((invocation) {
        recorder.setPaths.add(
          (invocation.positionalArguments[0]
                  as DocumentReference<Map<String, dynamic>>)
              .path,
        );
        recorder.sets.add(
          Map<String, dynamic>.from(
            invocation.positionalArguments[1] as Map,
          ),
        );
      });
      when(() => batch.commit()).thenAnswer((_) async {});
      pool.add(batch);
    }
    var nextBatch = 0;
    when(() => db.batch()).thenAnswer((_) => pool[nextBatch++]);
  });

  test('a completed job cascades applications, private docs and notifications',
      () async {
    final counts = await service.deleteJob(
      'j1',
      adminId: 'admin',
      reason: 'Test data',
    );

    expect(counts, {'jobRequests': 2, 'privateDocs': 1, 'notifications': 3});

    // Applications and their private children.
    expect(recorder.deleteCalled('jobRequests/r1'), isTrue);
    expect(recorder.deleteCalled('jobRequests/r2'), isTrue);
    // Owner/admin-only details under the job.
    expect(recorder.deleteCalled('jobs/j1/private/pin'), isTrue);
    // Notifications that would otherwise point at nothing.
    expect(recorder.deleteCalled('notifications/n0'), isTrue);
    expect(recorder.deleteCalled('notifications/n1'), isTrue);
    expect(recorder.deleteCalled('notifications/n2'), isTrue);
    // The job itself.
    expect(recorder.deleteCalled('jobs/j1'), isTrue);
  });

  test('the audit record is written in the same batch as the job delete',
      () async {
    await service.deleteJob('j1', adminId: 'admin', reason: 'Duplicate');

    final jobBatch = recorder.deleted.indexWhere((b) => b.contains('jobs/j1'));
    expect(jobBatch, isNot(-1));
    expect(
      recorder.auditPath,
      'deletedJobs/j1',
      reason: 'audit id must equal the job id',
    );

    final audit = recorder.audit;
    expect(audit['jobId'], 'j1');
    expect(audit['title'], 'Leaky kitchen sink');
    expect(audit['category'], 'plumbing');
    expect(audit['ownerId'], 'client');
    expect(audit['workerId'], 'worker');
    expect(audit['status'], 'completed');
    expect(audit['budgetMin'], 1500);
    expect(audit['budgetMax'], 3000);
    expect(audit['createdAt'], isA<Timestamp>());
    expect(audit['deletedAt'], isA<FieldValue>());
    expect(audit['deletedBy'], 'admin');
    expect(audit['reason'], 'Duplicate');
    expect(audit['cascaded'], {
      'jobRequests': 2,
      'privateDocs': 1,
      'notifications': 3,
    });
  });

  test('the audit record carries exactly the agreed fields', () async {
    await service.deleteJob('j1', adminId: 'admin', reason: 'Requested by user');

    expect(
      recorder.audit.keys.toSet(),
      {
        'jobId', 'title', 'category', 'ownerId', 'workerId', 'status',
        'budgetMin', 'budgetMax', 'createdAt', 'deletedAt', 'deletedBy',
        'reason', 'cascaded', 'skipped',
      },
      reason: 'the web dashboard writes this same shape (admin/src/api/jobs.ts)',
    );
    expect(
      (recorder.audit['cascaded'] as Map).keys.toSet(),
      {'jobRequests', 'privateDocs', 'notifications'},
    );
    // `skipped` names the clean-ups the rules do not let an admin perform
    // (notifications and the private subcollections), so the record says what
    // was left behind instead of implying a complete cascade.
    expect(recorder.audit['skipped'], isA<List<dynamic>>());
  });

  test('payments and reviews are never touched', () async {
    await service.deleteJob('j1', adminId: 'admin', reason: 'Spam');

    final touched = recorder.deleted.expand((batch) => batch).join(' ');
    expect(touched, isNot(contains('payments')));
    expect(touched, isNot(contains('reviews')));
    verifyNever(() => db.collection('payments'));
    verifyNever(() => db.collection('reviews'));
  });

  test('a reason is mandatory before anything is read or written', () async {
    await expectLater(
      service.deleteJob('j1', adminId: 'admin', reason: '   '),
      throwsArgumentError,
    );
    verifyNever(() => db.batch());
  });

  test('a non-admin cannot delete, and no batch is written', () async {
    when(() => adminSnap.data()).thenReturn({'role': 'user'});

    await expectLater(
      service.deleteJob('j1', adminId: 'admin', reason: 'Test data'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('admin-only'),
        ),
      ),
    );
    verifyNever(() => db.batch());
  });

  test('a job that no longer exists reports that instead of pretending', () async {
    when(() => jobSnap.exists).thenReturn(false);

    await expectLater(
      service.deleteJob('j1', adminId: 'admin', reason: 'Test data'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no longer exists'),
        ),
      ),
    );
    verifyNever(() => db.batch());
  });

  test('a failing chunk stops the cascade, names the step and keeps the job',
      () async {
    var commits = 0;
    final failing = <_Batch>[];
    for (var i = 0; i < 4; i++) {
      final batch = _Batch();
      when(() => batch.delete(any())).thenAnswer((_) {});
      when(() => batch.set<Map<String, dynamic>>(any(), any())).thenAnswer((_) {});
      when(() => batch.commit()).thenAnswer((_) async {
        commits++;
        if (commits == 2) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
      });
      failing.add(batch);
    }
    var failingNext = 0;
    when(() => db.batch()).thenAnswer((_) => failing[failingNext++]);

    await expectLater(
      service.deleteJob('j1', adminId: 'admin', reason: 'Test data'),
      throwsA(
        isA<StateError>()
            .having((e) => e.message, 'message', contains('private documents'))
            .having((e) => e.message, 'message', contains('unavailable')),
      ),
    );
    // Two phases committed and then it stopped: no third batch was even
    // created, and the job delete is the last phase, so it never happened.
    expect(commits, 2);
    expect(recorder.deleteCalled('jobs/j1'), isFalse);
    expect(recorder.setPaths, isNot(contains('deletedJobs/j1')));
  });

  test('more than 500 operations are split across batches', () async {
    // 501 applications, each with no private subdocument.
    final noChildren = _Coll();
    final noChildrenSnap = _QuerySnap();
    when(() => noChildrenSnap.docs).thenReturn([]);
    when(() => noChildren.get()).thenAnswer((_) async => noChildrenSnap);

    final many = List.generate(501, (i) {
      final ref = docWith('jobRequests/r$i');
      when(() => ref.collection('private')).thenReturn(noChildren);
      final snap = _QDocSnap();
      when(() => snap.reference).thenReturn(ref);
      return snap;
    });
    when(() => requestsSnap.docs).thenReturn(many);

    final counts = await service.deleteJob(
      'j1',
      adminId: 'admin',
      reason: 'Test data',
    );

    expect(counts['jobRequests'], 501);
    // A single batch may hold at most 500 writes.
    expect(recorder.deleted.every((batch) => batch.length <= 500), isTrue);
    expect(recorder.deleteCount, greaterThanOrEqualTo(501));
    // The job delete still happens, in the final batch.
    expect(recorder.deleteCalled('jobs/j1'), isTrue);
  });
}
