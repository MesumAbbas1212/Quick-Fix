// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/profile_service.dart';
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
void main() {
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  test('saved IDs are strings, deduplicated and never denormalized profiles', () {
    expect(ProfileService.savedWorkerIds(['w', 'w', '', 'bad/path', 5, {'name': 'not an ID'}]), ['w']); expect(ProfileService.savedWorkerIds(null), isEmpty);
  });
  test('optional UserModel saved IDs preserve legacy documents and copyWith', () {
    final old = UserModel.fromMap({'role': 'user'}, 'u'); expect(old.savedWorkers, isEmpty);
    final saved = old.copyWith(savedWorkers: ['w']); expect(saved.toMap()['savedWorkers'], ['w']); expect(old.savedWorkers, isEmpty);
  });
  test('explicit save/remove transactions are idempotent', () async {
    for (final saved in [true, false]) {
      final db = MockFirestore(); final users = MockCollection(); final ref = MockRef(); final snapshot = MockSnapshot(); final transaction = MockTransaction();
      when(() => db.collection('users')).thenReturn(users); when(() => users.doc('u')).thenReturn(ref); when(() => snapshot.exists).thenReturn(true);
      when(() => snapshot.data()).thenReturn({'savedWorkers': ['w']}); when(() => transaction.get(ref)).thenAnswer((_) async => snapshot);
      when(() => transaction.update(ref, any())).thenReturn(transaction);
      when(() => db.runTransaction<void>(any())).thenAnswer((invocation) async { await (invocation.positionalArguments.first as Future<void> Function(Transaction))(transaction); });
      await ProfileService(firestore: db).setWorkerSaved(uid: 'u', workerId: 'w', saved: saved);
      final update = verify(() => transaction.update(ref, captureAny())).captured.single as Map<String, dynamic>;
      expect(update['savedWorkers'], saved ? ['w'] : []);
    }
  });
}
