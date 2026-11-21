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

  test('resolveReport transaction updates report and linked dispute together', () async {
    final db = _Db(); final auth = _Auth(); final reports = _Collection(); final disputes = _Collection(); final reportRef = _Document(); final disputeRef = _Document();
    final tx = _Transaction(); final report = _DocSnapshot(); final dispute = _DocSnapshot();
    when(() => db.collection('reports')).thenReturn(reports); when(() => db.collection('disputes')).thenReturn(disputes);
    when(() => reports.doc('r1')).thenReturn(reportRef); when(() => disputes.doc('d1')).thenReturn(disputeRef);
    when(() => report.exists).thenReturn(true); when(() => report.data()).thenReturn({'status': 'open', 'reporterId': 'c', 'reportedId': 'w', 'jobId': 'j', 'disputeId': 'd1'});
    when(() => dispute.exists).thenReturn(true); when(() => dispute.data()).thenReturn({'raisedBy': 'c', 'againstId': 'w', 'jobId': 'j'});
    when(() => tx.get(reportRef)).thenAnswer((_) async => report); when(() => tx.get(disputeRef)).thenAnswer((_) async => dispute);
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async => await (call.positionalArguments.first as Future<void> Function(Transaction))(tx));
    await AdminService(firestore: db, auth: auth).resolveReport(reportId: 'r1', status: 'resolved', note: ' Reviewed ', resolvedBy: 'admin');
    verify(() => tx.update(reportRef, any())).called(1); verify(() => tx.update(disputeRef, any())).called(1);
    final reportUpdate = verify(() => tx.update(reportRef, captureAny())).captured.single as Map<String, dynamic>;
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
    when(() => tx.get(proofRef)).thenAnswer((_) async => proof); when(() => tx.get(workerRef)).thenAnswer((_) async => worker);
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async => await (call.positionalArguments.first as Future<void> Function(Transaction))(tx));
    await AdminService(firestore: db, auth: auth).reviewVerification('worker-1', 'verified', note: 'External check completed');
    verify(() => tx.update(proofRef, any())).called(1); verify(() => tx.update(workerRef, any())).called(1);
  });
}
