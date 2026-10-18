import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/services/account_access_service.dart';
class MockAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockInfo extends Mock implements UserInfo {}
class MockCredential extends Mock implements UserCredential {}
void main() {
  late MockAuth auth; late MockUser user; late AccountAccessService service;
  setUpAll(() { registerFallbackValue(EmailAuthProvider.credential(email: 'c@example.com', password: 'password')); });
  setUp(() {
    auth = MockAuth(); user = MockUser(); final info = MockInfo();
    when(() => auth.currentUser).thenReturn(user); when(() => user.uid).thenReturn('u'); when(() => user.email).thenReturn('c@example.com');
    when(() => info.providerId).thenReturn('password'); when(() => user.providerData).thenReturn([info]);
    when(() => user.reauthenticateWithCredential(any())).thenAnswer((_) async => MockCredential());
    when(() => user.getIdToken(true)).thenAnswer((_) async => 'fresh-token'); when(() => user.delete()).thenAnswer((_) async {});
    service = AccountAccessService(auth: auth);
  });
  test('reauthenticates and refreshes the ID token before cleanup may start', () async {
    await service.reauthenticate('u', 'password');
    verifyInOrder([() => user.reauthenticateWithCredential(any()), () => user.getIdToken(true)]);
    verifyNever(() => user.delete());
  });
  test('wrong credentials are mapped without exposing provider exceptions', () async {
    when(() => user.reauthenticateWithCredential(any())).thenThrow(FirebaseAuthException(code: 'wrong-password'));
    await expectLater(service.reauthenticate('u', 'bad'), throwsA(isA<AccountDeletionException>().having((error) => error.message, 'message', contains('Password was not accepted'))));
    verifyNever(() => user.getIdToken(true)); verifyNever(() => user.delete());
  });
  test('does not authenticate or delete another current account', () async {
    await expectLater(service.reauthenticate('different', 'password'), throwsA(isA<AccountDeletionException>()));
    await expectLater(service.deleteCurrent('different'), throwsA(isA<AccountDeletionException>())); verifyNever(() => user.delete());
  });
  test('an unsupported provider does not pretend password reauth succeeded', () async {
    when(() => user.providerData).thenReturn([]);
    await expectLater(service.reauthenticate('u', 'password'), throwsA(isA<AccountDeletionException>())); verifyNever(() => user.reauthenticateWithCredential(any()));
  });
  test('Auth deletion failure reports a recoverable incomplete flow', () async {
    when(() => user.delete()).thenThrow(FirebaseAuthException(code: 'requires-recent-login'));
    await expectLater(service.deleteCurrent('u'), throwsA(isA<AccountDeletionException>().having((error) => error.message, 'message', contains('next sign-in'))));
  });
}
