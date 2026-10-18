import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickfix/models/account_deletion_policy.dart';

/// Authentication boundary: reauthenticate before *any* cleanup marker/write.
class AccountAccessService {
  final FirebaseAuth? _injectedAuth;
  AccountAccessService({FirebaseAuth? auth}) : _injectedAuth = auth;
  late final FirebaseAuth _auth = _injectedAuth ?? FirebaseAuth.instance;
  void ensureCurrent(String uid) {
    if (_auth.currentUser?.uid != uid) throw const AccountDeletionException('The signed-in account changed. Sign in to the intended account and retry.');
  }
  Future<void> reauthenticate(String uid, String password) async {
    ensureCurrent(uid);
    final user = _auth.currentUser!;
    if (password.isEmpty || user.email == null || !user.providerData.any((provider) => provider.providerId == 'password')) {
      throw const AccountDeletionException('This flow requires the current email/password account. Sign in again with that account before deleting.');
    }
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password))
        .timeout(const Duration(seconds: 15));
      // Refresh auth_time so Firestore cleanup rules see the recent login.
      await user.getIdToken(true).timeout(const Duration(seconds: 10));
      ensureCurrent(uid);
    } on FirebaseAuthException catch (error) {
      if (const {'wrong-password', 'invalid-credential', 'invalid-login-credentials'}.contains(error.code)) {
        throw const AccountDeletionException('Password was not accepted. No new cleanup was started. A previous incomplete attempt may still need resuming.');
      }
      throw const AccountDeletionException('Could not reauthenticate. Check your connection and password, then retry. No new cleanup was started.');
    }
  }
  Future<void> deleteCurrent(String uid) async {
    ensureCurrent(uid);
    try { await _auth.currentUser!.delete().timeout(const Duration(seconds: 15)); }
    on FirebaseAuthException catch (_) {
      throw const AccountDeletionException('Profile cleanup finished, but Auth deletion was not confirmed. Re-enter your password and retry; unfinished deletion is recoverable at next sign-in.');
    }
  }
}
