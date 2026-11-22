// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/admin_service.dart';

class _Db extends Mock implements FirebaseFirestore {}
class _Auth extends Mock implements FirebaseAuth {}
class _User extends Mock implements User {}
class _Collection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class _Document extends Mock implements DocumentReference<Map<String, dynamic>> {}
class _Query extends Mock implements Query<Map<String, dynamic>> {}
class _Aggregate extends Mock implements AggregateQuery {}
class _AggregateSnapshot extends Mock implements AggregateQuerySnapshot {}
class _Transaction extends Mock implements Transaction {}
class _DocSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class _QuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class _JobDocument extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
void main() {
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  test('counts parses aggregate totals without fetching document rows', () async {
    final db = _Db(); final auth = _Auth(); final coll = _Collection(); final query = _Query(); final aggregate = _Aggregate(); final result = _AggregateSnapshot();
    when(() => db.collection(any())).thenReturn(coll); when(() => coll.count()).thenReturn(aggregate); when(() => aggregate.get()).thenAnswer((_) async => result);
    when(() => coll.where('status', isEqualTo: 'open')).thenReturn(query); when(() => query.count()).thenReturn(aggregate); when(() => result.count).thenReturn(7);
    final counts = await AdminService(firestore: db, auth: auth).counts();
    expect(counts.users, 7); expect(counts.workers, 7); expect(counts.jobs, 7); expect(counts.openReports, 7);
    verify(() => coll.count()).called(3); verify(() => query.count()).called(1);
  });

  test('watchJobs orders and limits before client-side status filtering', () async {
    final db = _Db();
    final auth = _Auth();
    final jobs = _Collection();
    final query = _Query();
    final snapshot = _QuerySnapshot();
    final openJob = _JobDocument();
    final completedJob = _JobDocument();
    final users = _Collection();
    final clientRef = _Document();
    final workerRef = _Document();
    final clientSnapshot = _DocSnapshot();
    final workerSnapshot = _DocSnapshot();
    final createdAt = Timestamp.fromDate(DateTime(2026, 10, 18));

    when(() => db.collection('jobs')).thenReturn(jobs);
    when(() => jobs.orderBy('createdAt', descending: true)).thenReturn(query);
    when(() => query.limit(50)).thenReturn(query);
    when(() => query.snapshots()).thenAnswer((_) => Stream.value(snapshot));
    when(() => snapshot.docs).thenReturn([openJob, completedJob]);
    when(() => openJob.id).thenReturn('j-open');
    when(() => openJob.data()).thenReturn({
      'title': 'Fix sink', 'category': 'plumbing', 'status': 'open',
      'budgetMin': 10000, 'budgetMax': 20000, 'address': 'Islamabad',
      'userId': 'client-1', 'workerId': 'worker-1', 'createdAt': createdAt,
      'preferredDate': createdAt,
    });
    when(() => completedJob.id).thenReturn('j-done');
    when(() => completedJob.data()).thenReturn({
      'title': 'Old job', 'status': 'completed', 'createdAt': createdAt,
    });
    when(() => db.collection('users')).thenReturn(users);
    when(() => users.doc('client-1')).thenReturn(clientRef);
    when(() => users.doc('worker-1')).thenReturn(workerRef);
    when(() => clientRef.get()).thenAnswer((_) async => clientSnapshot);
    when(() => workerRef.get()).thenAnswer((_) async => workerSnapshot);
    when(() => clientSnapshot.exists).thenReturn(true);
    when(() => clientSnapshot.data()).thenReturn({'fullName': 'Client'});
    when(() => workerSnapshot.exists).thenReturn(true);
    when(() => workerSnapshot.data()).thenReturn({'fullName': 'Worker'});

    final rows = await AdminService(firestore: db, auth: auth)
        .watchJobs(status: 'open', limit: 50).first;
    expect(rows, hasLength(1));
    expect(rows.single.id, 'j-open');
    expect(rows.single.clientName, 'Client');
    expect(rows.single.workerName, 'Worker');
    expect(rows.single.budgetMax, 20000);
    verify(() => jobs.orderBy('createdAt', descending: true)).called(1);
    verify(() => query.limit(50)).called(1);
    verifyNever(() => jobs.where('status', isEqualTo: 'open'));
  });

  test('resolveReport transaction updates report and linked dispute together', () async {
    final db = _Db(); final auth = _Auth(); final reports = _Collection(); final disputes = _Collection(); final reportRef = _Document(); final disputeRef = _Document();
    final tx = _Transaction(); final report = _DocSnapshot(); final dispute = _DocSnapshot();
    when(() => db.collection('reports')).thenReturn(reports); when(() => db.collection('disputes')).thenReturn(disputes);
    when(() => reports.doc('r1')).thenReturn(reportRef); when(() => disputes.doc('d1')).thenReturn(disputeRef);
    when(() => report.exists).thenReturn(true); when(() => report.data()).thenReturn({'status': 'open', 'reporterId': 'c', 'reportedId': 'w', 'jobId': 'j', 'disputeId': 'd1'});
    when(() => dispute.exists).thenReturn(true); when(() => dispute.data()).thenReturn({'raisedBy': 'c', 'againstId': 'w', 'jobId': 'j'});
    when(() => tx.update(reportRef, any())).thenReturn(tx);
    when(() => tx.update(disputeRef, any())).thenReturn(tx);
    when(() => tx.get(reportRef)).thenAnswer((_) async => report); when(() => tx.get(disputeRef)).thenAnswer((_) async => dispute);
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async => await (call.positionalArguments.first as Future<void> Function(Transaction))(tx));
    await AdminService(firestore: db, auth: auth).resolveReport(reportId: 'r1', status: 'resolved', note: ' Reviewed ', resolvedBy: 'admin');
    final reportUpdate = verify(() => tx.update(reportRef, captureAny())).captured.single as Map<String, dynamic>;
    verify(() => tx.update(disputeRef, captureAny())).called(1);
    expect(reportUpdate['status'], 'resolved'); expect(reportUpdate['resolutionNote'], 'Reviewed'); expect(reportUpdate['resolvedBy'], 'admin');
  });

  test('verification review transaction writes both private proof and worker summary', () async {
    final db = _Db(); final auth = _Auth(); final current = _User();
    final proofs = _Collection(); final workers = _Collection(); final proofRef = _Document(); final workerRef = _Document(); final tx = _Transaction();
    final proof = _DocSnapshot(); final worker = _DocSnapshot();
    when(() => auth.currentUser).thenReturn(current); when(() => current.uid).thenReturn('admin');
    when(() => db.collection('workerVerifications')).thenReturn(proofs); when(() => db.collection('workers')).thenReturn(workers);
    when(() => proofs.doc('worker-1')).thenReturn(proofRef); when(() => workers.doc('worker-1')).thenReturn(workerRef);
    when(() => proof.exists).thenReturn(true); when(() => proof.data()).thenReturn({'status': 'pending', 'consent': true, 'cnicFrontPath': '/local/front', 'cnicBackPath': '/local/back', 'selfiePath': '/local/selfie', 'submittedAt': Timestamp.fromDate(DateTime(2026))});
    when(() => worker.exists).thenReturn(true);
    when(() => tx.update(proofRef, any())).thenReturn(tx);
    when(() => tx.update(workerRef, any())).thenReturn(tx);
    when(() => tx.get(proofRef)).thenAnswer((_) async => proof); when(() => tx.get(workerRef)).thenAnswer((_) async => worker);
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async => await (call.positionalArguments.first as Future<void> Function(Transaction))(tx));
    await AdminService(firestore: db, auth: auth).reviewVerification('worker-1', 'verified', note: 'External check completed');
    verify(() => tx.update(proofRef, captureAny())).called(1); verify(() => tx.update(workerRef, captureAny())).called(1);
  });
}
