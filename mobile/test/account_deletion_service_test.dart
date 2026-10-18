import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/services/account_access_service.dart';
import 'package:quickfix/services/account_deletion_repository.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/network_status_service.dart';
import 'package:quickfix/services/preferences_service.dart';
class MockAccess extends Mock implements AccountAccessService {}
class MockRepository extends Mock implements AccountDeletionRepository {}
class MockImages extends Mock implements LocalImageStore {}
class MockPreferences extends Mock implements PreferencesService {}
void main() {
  late MockAccess access; late MockRepository repository; late MockImages images; late MockPreferences preferences;
  late NetworkStatusService network; late AccountDeletionService service; late List<String> events;
  setUp(() {
    events = []; access = MockAccess(); repository = MockRepository(); images = MockImages(); preferences = MockPreferences(); network = NetworkStatusService();
    when(() => access.reauthenticate('u', 'password')).thenAnswer((_) async { events.add('reauth'); });
    when(() => access.deleteCurrent('u')).thenAnswer((_) async { events.add('auth-delete'); });
    when(() => repository.synchronize()).thenAnswer((_) async { events.add('sync'); });
    when(() => repository.begin('u')).thenAnswer((_) async { events.add('begin'); });
    when(() => repository.hasActiveJobs('u')).thenAnswer((_) async => false);
    when(() => repository.startCleanup('u')).thenAnswer((_) async { events.add('cleaning'); });
    when(() => repository.cleanup('u')).thenAnswer((_) async { events.add('content'); });
    when(() => repository.deleteProfiles('u')).thenAnswer((_) async { events.add('profiles'); });
    when(() => repository.cancelChecking('u')).thenAnswer((_) async { events.add('unpause'); });
    when(() => images.clearAccountImages('u')).thenAnswer((_) async { events.add('files'); });
    when(() => preferences.clearAccountCache()).thenAnswer((_) async { events.add('preferences'); });
    service = AccountDeletionService(accountAccessService: access, repository: repository, imageStore: images, preferencesService: preferences, networkStatusService: network);
  });
  tearDown(() { network.dispose(); });
  Future<void> run() => service.deleteAccount(uid: 'u', password: 'password');
  test('reauth precedes every write and profile cleanup precedes Auth deletion', () async {
    await run(); expect(events, ['reauth', 'sync', 'begin', 'cleaning', 'content', 'files', 'preferences', 'profiles', 'auth-delete']);
    verify(() => access.ensureCurrent('u')).called(3);
  });
  test('failed reauth cannot begin any cleanup', () async {
    when(() => access.reauthenticate('u', 'password')).thenThrow(const AccountDeletionException('Wrong password'));
    await expectLater(run(), throwsA(isA<AccountDeletionException>()));
    verifyNever(() => repository.begin('u')); verifyNever(() => repository.cleanup('u')); verifyNever(() => access.deleteCurrent('u'));
  });
  test('active work removes only a checking marker and leaves content/Auth untouched', () async {
    when(() => repository.hasActiveJobs('u')).thenAnswer((_) async => true);
    await expectLater(run(), throwsA(isA<AccountDeletionException>().having((error) => error.message, 'message', contains('Active assigned'))));
    verify(() => repository.cancelChecking('u')).called(1); verifyNever(() => repository.startCleanup('u'));
    verifyNever(() => repository.deleteProfiles('u')); verifyNever(() => access.deleteCurrent('u'));
  });
  test('server synchronization failure never deletes profiles', () async {
    when(() => repository.synchronize()).thenThrow(StateError('unacknowledged writes'));
    await expectLater(run(), throwsA(isA<AccountDeletionException>())); verifyNever(() => repository.begin('u')); verifyNever(() => access.deleteCurrent('u'));
  });
  test('partial cleanup errors are not called success and can be resumed', () async {
    when(() => repository.cleanup('u')).thenThrow(StateError('offline after first page'));
    await expectLater(run(), throwsA(isA<AccountDeletionException>().having((error) => error.message, 'message', contains('Some data may already be removed'))));
    verifyNever(() => repository.deleteProfiles('u')); verifyNever(() => access.deleteCurrent('u'));
    when(() => repository.cleanup('u')).thenAnswer((_) async {}); await run(); verify(() => access.deleteCurrent('u')).called(1);
  });
  test('file/cache cleanup failure leaves Auth available for retry', () async {
    when(() => images.clearAccountImages('u')).thenThrow(StateError('device storage unavailable'));
    await expectLater(run(), throwsA(isA<AccountDeletionException>())); verifyNever(() => repository.deleteProfiles('u')); verifyNever(() => access.deleteCurrent('u'));
  });
  test('profile write failure cannot delete Auth first', () async {
    when(() => repository.deleteProfiles('u')).thenThrow(StateError('permission'));
    await expectLater(run(), throwsA(isA<AccountDeletionException>())); verifyNever(() => access.deleteCurrent('u'));
  });
  test('Auth failure remains recoverable without claiming a rollback', () async {
    when(() => access.deleteCurrent('u')).thenThrow(const AccountDeletionException('Auth deletion was not confirmed. Retry.'));
    await expectLater(run(), throwsA(isA<AccountDeletionException>())); verify(() => repository.deleteProfiles('u')).called(1);
    when(() => access.deleteCurrent('u')).thenAnswer((_) async {}); await run(); verify(() => repository.begin('u')).called(2);
  });
  test('parallel attempts cannot race destructive cleanup', () async {
    final pending = Completer<void>(); when(() => access.reauthenticate('u', 'password')).thenAnswer((_) => pending.future);
    final first = run(); await expectLater(run(), throwsA(isA<AccountDeletionException>()));
    pending.complete(); await first; verify(() => repository.begin('u')).called(1);
  });
}
