import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/services/account_access_service.dart';
import 'package:quickfix/services/account_deletion_repository.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/network_status_service.dart';
import 'package:quickfix/services/preferences_service.dart';

class AccountDeletionService {
  final AccountAccessService _access;
  final AccountDeletionRepository _repository;
  final LocalImageStore _images;
  final PreferencesService _preferences;
  final NetworkStatusService _network;
  static final _running = <String>{};
  AccountDeletionService({FirebaseAuth? auth, FirebaseFirestore? firestore, AccountAccessService? accountAccessService,
    AccountDeletionRepository? repository, LocalImageStore? imageStore, PreferencesService? preferencesService,
    NetworkStatusService? networkStatusService})
      : _access = accountAccessService ?? AccountAccessService(auth: auth),
        _repository = repository ?? AccountDeletionRepository(firestore: firestore),
        _images = imageStore ?? const LocalImageStore(), _preferences = preferencesService ?? PreferencesService(),
        _network = networkStatusService ?? NetworkStatusService.instance;

  Future<void> deleteAccount({required String uid, required String password}) async {
    if (!_running.add(uid)) throw const AccountDeletionException('A deletion attempt for this account is still running. Wait for it to finish before retrying.');
    var started = false;
    try {
      try { await _access.reauthenticate(uid, password); }
      on AccountDeletionException { rethrow; }
      catch (_) { throw const AccountDeletionException('Could not reauthenticate. No new cleanup was started. Check your password and connection, then retry.'); }
      _access.ensureCurrent(uid);
      await _repository.synchronize();
      await _repository.begin(uid); started = true;
      if (await _repository.hasActiveJobs(uid)) {
        await _repository.cancelChecking(uid);
        throw const AccountDeletionException('Active assigned or in-progress work blocks deletion. This attempt did not start content cleanup. Complete or cancel that work first; sign out and sign in again if you are on the recovery page. If an earlier cleanup already paused this account, ask the operator to resolve its active work.');
      }
      await _repository.startCleanup(uid);
      await _repository.cleanup(uid);
      _access.ensureCurrent(uid);
      await _images.clearAccountImages(uid).timeout(const Duration(seconds: 8));
      await _preferences.clearAccountCache().timeout(const Duration(seconds: 5));
      await _repository.deleteProfiles(uid); // Private proof + worker + user, BEFORE Auth.
      _access.ensureCurrent(uid);
      await _access.deleteCurrent(uid);
      _network.reset();
    } on AccountDeletionException { rethrow; }
    catch (_) {
      throw AccountDeletionException(started
        ? 'Deletion did not finish. Some data may already be removed and the account may be paused. Re-enter your password and retry to resume; next sign-in also offers recovery. No rollback or full erasure is claimed.'
        : 'Could not begin deletion. No new content cleanup was started. A previous incomplete attempt may still need resuming. Check your connection and retry.');
    } finally { _running.remove(uid); }
  }
}
