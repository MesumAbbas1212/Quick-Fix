// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
class MockAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocument extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
void main() {
  late MockAuth auth; late MockUser current; late MockFirestore firestore; late MockSnapshot profile; late MockSnapshot marker; late AuthService service;
  setUp(() {
    auth = MockAuth(); current = MockUser(); firestore = MockFirestore(); profile = MockSnapshot(); marker = MockSnapshot();
    final users = MockCollection(); final markers = MockCollection(); final profileRef = MockDocument(); final markerRef = MockDocument();
    when(() => auth.currentUser).thenReturn(current); when(() => current.uid).thenReturn('u'); when(() => current.email).thenReturn('c@example.com');
    when(() => firestore.collection('users')).thenReturn(users); when(() => firestore.collection('accountDeletions')).thenReturn(markers);
    when(() => users.doc(any())).thenReturn(profileRef); when(() => markers.doc('u')).thenReturn(markerRef);
    when(() => profileRef.get()).thenAnswer((_) async => profile); when(() => markerRef.get(const GetOptions(source: Source.server))).thenAnswer((_) async => marker);
    when(() => profile.exists).thenReturn(false); when(() => marker.exists).thenReturn(true);
    service = AuthService(auth: auth, firestore: firestore);
  });
  test('missing profile plus a private marker returns a recovery model after sign-in', () async {
    final user = await service.getUserProfile('u'); expect(user, isNotNull); expect(user!.deletionPending, isTrue);
    expect(user.uid, 'u'); expect(user.email, 'c@example.com'); expect(user.toMap().containsKey('deletionPending'), isFalse);
  });
  test('existing profile is still gated if cleanup was interrupted before deleting it', () async {
    when(() => profile.exists).thenReturn(true); when(() => profile.id).thenReturn('u'); when(() => profile.data()).thenReturn({'email': 'c@example.com', 'role': 'worker'});
    final user = await service.getUserProfile('u'); expect(user!.deletionPending, isTrue); expect(user.role, UserRole.worker);
  });
  test('foreign profile reads never probe its private deletion record', () async {
    when(() => profile.exists).thenReturn(true); when(() => profile.id).thenReturn('w'); when(() => profile.data()).thenReturn({'role': 'worker'});
    expect((await service.getUserProfile('w'))!.deletionPending, isFalse); verifyNever(() => firestore.collection('accountDeletions'));
  });
  test('the legacy no-argument deletion entry cannot bypass reauthentication', () async {
    await expectLater(service.deleteAccount(), throwsA(isA<AccountDeletionException>())); verifyNever(() => firestore.collection(any()));
  });
  test('a public profile field cannot spoof private recovery state', () {
    final user = UserModel.fromMap({'role': 'user', 'deletionPending': true}, 'u'); expect(user.deletionPending, isFalse);
    expect(user.copyWith(deletionPending: true).toMap().containsKey('deletionPending'), isFalse);
  });
}
