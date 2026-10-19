// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/payout_service.dart';
class MockDB extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
void main() {
  test('uncertain-attempt retry returns the recorded amount, never a second withdrawal', () async {
    final db = MockDB(); final collection = MockCollection(); final ref = MockRef(); final snapshot = MockSnapshot();
    when(() => db.collection('payouts')).thenReturn(collection); when(() => collection.doc('same-attempt')).thenReturn(ref);
    when(() => ref.get(const GetOptions(source: Source.server))).thenAnswer((_) async => snapshot); when(() => snapshot.exists).thenReturn(true); when(() => snapshot.id).thenReturn('same-attempt');
    when(() => snapshot.data()).thenReturn({'workerId': 'w', 'amountPaisa': 1234, 'method': 'bank', 'accountRef': 'DEMO-OLD', 'status': 'pending'});
    final result = await PayoutService(firestore: db).request(uid: 'w', requestId: 'same-attempt', amountPaisa: 9999, method: 'jazzcash', accountRef: 'DEMO-NEW');
    expect(result.amountPaisa, 1234); expect(result.method, 'bank'); verifyNever(() => db.waitForPendingWrites());
  });
  test('invalid withdrawal arguments fail before backend access', () async {
    final db = MockDB(); await expectLater(PayoutService(firestore: db).request(uid: 'w', requestId: 'p', amountPaisa: 0, method: 'bank', accountRef: 'DEMO'), throwsArgumentError); verifyNever(() => db.collection(any()));
  });
}
