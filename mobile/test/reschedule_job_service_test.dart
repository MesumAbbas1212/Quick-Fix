// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/job_service.dart';
class MockDB extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
void main() {
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  test('only an active owning client can change schedule; terminal changes write nothing', () async {
    final db = MockDB(); final collection = MockCollection(); final ref = MockRef(); final snapshot = MockSnapshot(); final transaction = MockTransaction();
    when(() => db.collection('jobs')).thenReturn(collection); when(() => collection.doc('j')).thenReturn(ref);
    when(() => transaction.get(ref)).thenAnswer((_) async => snapshot); when(() => snapshot.data()).thenReturn({'userId': 'other', 'status': 'assigned'});
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async { await (call.positionalArguments.first as Future<void> Function(Transaction))(transaction); });
    final service = JobService(firestore: db);
    Future<void> change() => service.changeSchedule(jobId: 'j', ownerId: 'u', cancel: true, date: DateTime(2026), reason: 'Plans changed');
    await expectLater(change(), throwsStateError);
    when(() => snapshot.data()).thenReturn({'userId': 'u', 'status': 'completed'}); await expectLater(change(), throwsStateError);
    verifyNever(() => transaction.update(ref, any()));
  });
}
