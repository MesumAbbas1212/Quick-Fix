// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/saved_address.dart';
import 'package:quickfix/services/profile_service.dart';
class MockDB extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
void main() {
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  test('address decoding preserves a legacy pin without inventing coordinates', () {
    final addresses = SavedAddress.decode([{'label': 'Home', 'address': 'Attock', 'location': const GeoPoint(33.77, 72.36)}]);
    expect(addresses.single.id, 'legacy-0'); expect(addresses.single.selection.address, 'Attock'); expect(addresses.single.toMap()['location'], const GeoPoint(33.77, 72.36));
    expect(SavedAddress.decode(null), isEmpty); expect(() => SavedAddress.decode([{'address': 'Missing pin'}]), throwsFormatException);
  });
  test('save validates before touching Firestore', () async {
    final db = MockDB(); await expectLater(ProfileService(firestore: db).saveAddress('u', const SavedAddress(label: '', address: 'Attock', location: GeoPoint(33, 72))), throwsArgumentError);
    verifyNever(() => db.collection(any()));
  });
  test('a legacy address migrates into a private replacement and leaves the public profile', () async {
    final db = MockDB(); final users = MockCollection(); final private = MockCollection(); final user = MockRef(); final book = MockRef(); final generated = MockRef();
    final account = MockSnapshot(); final record = MockSnapshot(); final transaction = MockTransaction();
    when(() => db.collection('users')).thenReturn(users); when(() => users.doc('u')).thenReturn(user); when(() => users.doc()).thenReturn(generated); when(() => generated.id).thenReturn('new');
    when(() => user.collection('private')).thenReturn(private); when(() => private.doc('addressBook')).thenReturn(book);
    when(() => transaction.get(user)).thenAnswer((_) async => account); when(() => transaction.get(book)).thenAnswer((_) async => record);
    when(() => account.exists).thenReturn(true); when(() => record.exists).thenReturn(false);
    when(() => account.data()).thenReturn({'addresses': [{'label': 'Home', 'address': 'Attock', 'location': const GeoPoint(33, 72)}]});
    when(() => transaction.set<Map<String, dynamic>>(book, any(), any())).thenReturn(transaction); when(() => transaction.update(user, any())).thenReturn(transaction);
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async { await (call.positionalArguments.first as Future<void> Function(Transaction))(transaction); });
    await ProfileService(firestore: db).saveAddress('u', const SavedAddress(label: 'Office', address: 'Islamabad', location: GeoPoint(33.7, 73)));
    final saved = verify(() => transaction.set<Map<String, dynamic>>(book, captureAny(), any())).captured.single as Map<String, dynamic>;
    expect(saved['addresses'], hasLength(2)); final scrub = verify(() => transaction.update(user, captureAny())).captured.single as Map<String, dynamic>;
    expect(scrub.keys, ['addresses']); expect(scrub['addresses'], isA<FieldValue>());
  });
}
