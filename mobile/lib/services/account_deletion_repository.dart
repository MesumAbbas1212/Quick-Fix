import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/account_deletion_policy.dart';

/// Server-confirmed, bounded, resumable cleanup for the currently implemented
/// collections. A retained private tombstone prevents stale sessions creating
/// new work. It is intentionally not a public user/profile tombstone.
class AccountDeletionRepository {
  final FirebaseFirestore? _injectedFirestore;
  final DateTime Function()? now;
  AccountDeletionRepository({FirebaseFirestore? firestore, this.now}) : _injectedFirestore = firestore;
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  DateTime? _deadline;
  int _processed = 0;
  void _budget() {
    if (_processed >= 1500 || (_deadline != null && (now ?? DateTime.now)().isAfter(_deadline!))) {
      throw const AccountDeletionException('This account needs another cleanup pass. Some data is already removed. Re-enter your password and retry to resume safely.');
    }
  }
  DocumentReference<Map<String, dynamic>> _marker(String uid) => _firestore.collection('accountDeletions').doc(uid);
  Future<void> synchronize() => _firestore.waitForPendingWrites().timeout(const Duration(seconds: 10));
  Future<void> begin(String uid) async {
    _processed = 0; _deadline = (now ?? DateTime.now)().add(const Duration(minutes: 2));
    await _firestore.runTransaction<void>((transaction) async {
      final reference = _marker(uid); final existing = await transaction.get(reference);
      if (!existing.exists) transaction.set(reference, {'state': 'checking', 'startedAt': FieldValue.serverTimestamp()});
    }).timeout(const Duration(seconds: 10));
  }
  Future<bool> hasActiveJobs(String uid) async {
    for (final field in ['userId', 'workerId']) {
      final result = await _firestore.collection('jobs').where(field, isEqualTo: uid)
        .where('status', whereIn: ['assigned', 'inProgress']).limit(1).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 10));
      if (result.metadata.isFromCache || result.metadata.hasPendingWrites) throw const AccountDeletionException('Waiting for server-confirmed work status. Restore your connection and retry.');
      if (result.docs.isNotEmpty) return true;
    }
    return false;
  }
  Future<void> cancelChecking(String uid) async {
    await _firestore.runTransaction<void>((transaction) async {
      final ref = _marker(uid); final snapshot = await transaction.get(ref);
      // Never re-enable account writes after destructive cleanup has started.
      if (snapshot.data()?['state'] == 'checking') transaction.delete(ref);
    }).timeout(const Duration(seconds: 10));
  }
  Future<void> startCleanup(String uid) => _marker(uid).update({'state': 'cleaning', 'updatedAt': FieldValue.serverTimestamp()}).timeout(const Duration(seconds: 10));
  Future<void> _drain(Query<Map<String, dynamic>> query,
    Future<void> Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>) process) async {
    while (true) {
      _budget(); await synchronize();
      final snapshot = await query.limit(100).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 10));
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) throw const AccountDeletionException('Cleanup is waiting for server confirmation. Reconnect and retry to resume.');
      if (snapshot.docs.isEmpty) return;
      _processed += snapshot.docs.length;
      await process(snapshot.docs);
      // The processed documents no longer match this account-scoped query;
      // repeatedly drain the first page instead of skipping after mutations.
    }
  }
  Future<void> _delete(Query<Map<String, dynamic>> query) => _drain(query, (documents) async {
    final batch = _firestore.batch(); for (final document in documents) { batch.delete(document.reference); }
    await batch.commit().timeout(const Duration(seconds: 10));
  });
  Future<void> cleanup(String uid) async {
    // Applications and reviews do not require parent documents to survive.
    for (final field in ['userId', 'workerId']) { await _delete(_firestore.collection('jobRequests').where(field, isEqualTo: uid)); }
    for (final field in ['reviewerId', 'workerId']) { await _delete(_firestore.collection('reviews').where(field, isEqualTo: uid)); }
    await _drain(_firestore.collection('conversations').where('participants', arrayContains: uid), (conversations) async {
      for (final conversation in conversations) {
        _budget();
        // Remove subcollections before the parent: participant rules depend on it.
        await _delete(conversation.reference.collection('messages'));
        await conversation.reference.delete().timeout(const Duration(seconds: 10));
      }
    });
    for (final field in ['userId', 'workerId']) {
      await _drain(_firestore.collection('jobs').where(field, isEqualTo: uid), (jobs) async {
        for (final job in jobs) {
          _budget();
          await _delete(_firestore.collection('jobRequests').where('jobId', isEqualTo: job.id));
          await _firestore.runTransaction<void>((transaction) async {
            final current = (await transaction.get(job.reference)).data();
            if (current == null || (current['userId'] != uid && current['workerId'] != uid)) return;
            final retained = AccountDeletionPolicy.retainedJob(current, uid);
            if (retained == null) { transaction.delete(job.reference); }
            else { transaction.set(job.reference, retained); }
          }).timeout(const Duration(seconds: 10));
        }
      });
    }
    for (final field in ['payerId', 'workerId']) {
      await _drain(_firestore.collection('payments').where(field, isEqualTo: uid), (receipts) async {
        for (final receipt in receipts) {
          _budget();
          await _firestore.runTransaction<void>((transaction) async {
            final data = (await transaction.get(receipt.reference)).data();
            if (data == null || (data['payerId'] != uid && data['workerId'] != uid)) return;
            transaction.set(receipt.reference, AccountDeletionPolicy.retainedReceipt(data, uid));
          }).timeout(const Duration(seconds: 10));
        }
      });
    }
  }
  Future<void> deleteProfiles(String uid) async {
    await synchronize();
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('workerVerifications').doc(uid));
    batch.delete(_firestore.collection('workers').doc(uid));
    batch.delete(_firestore.collection('users').doc(uid));
    batch.update(_marker(uid), {'state': 'authPending', 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit().timeout(const Duration(seconds: 10));
    // Auth is deleted by the orchestrator only after this commit acknowledges.
  }
}
