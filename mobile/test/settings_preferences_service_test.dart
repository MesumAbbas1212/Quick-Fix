// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/auth_service.dart';
class MockAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockDB extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
void main() {
  test('preference updates use a single nested field, not a stale full map', () async {
    final auth = MockAuth(); final db = MockDB(); final users = MockCollection(); final ref = MockRef();
    when(() => db.collection('users')).thenReturn(users); when(() => users.doc('u')).thenReturn(ref); when(() => ref.update(any())).thenAnswer((_) async {});
    final service = AuthService(auth: auth, firestore: db); await service.updateNotificationPreference(uid: 'u', key: 'messages', value: false);
    final change = verify(() => ref.update(captureAny())).captured.single as Map<Object, Object?>; expect(change['notificationPrefs.messages'], isFalse); expect(change.containsKey('notificationPrefs'), isFalse);
    await expectLater(service.updateNotificationPreference(uid: 'u', key: 'role', value: true), throwsArgumentError);
  });
  test('password reset targets Firebase Auth email, never a mutable profile value', () async {
    final auth = MockAuth(); final current = MockUser(); when(() => auth.currentUser).thenReturn(current); when(() => current.uid).thenReturn('u'); when(() => current.email).thenReturn('actual@example.com');
    when(() => auth.sendPasswordResetEmail(email: 'actual@example.com')).thenAnswer((_) async {});
    await AuthService(auth: auth, firestore: MockDB()).requestCurrentPasswordReset('u'); verify(() => auth.sendPasswordResetEmail(email: 'actual@example.com')).called(1);
    await expectLater(AuthService(auth: auth, firestore: MockDB()).requestCurrentPasswordReset('other'), throwsStateError);
  });
}
