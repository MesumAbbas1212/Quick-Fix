import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/models/job_model.dart';
void main() {
  Map<String, dynamic> job({String status = 'completed', String client = 'u', String? worker = 'w'}) => {
    'userId': client, 'workerId': worker, 'status': status, 'title': 'Ali at Street 1', 'description': 'Private details',
    'address': 'Home address', 'location': const GeoPoint(33, 73), 'images': ['/private/photo'], 'review': 'Contact Ali',
    'category': 'plumbing', 'budgetMin': 1000, 'budgetMax': 2000, 'completedAt': Timestamp.fromDate(DateTime(2026, 10, 18)),
    'legacyClientName': 'Ali', 'extra': {'phone': 'private'}, 'paymentStatus': 'paid',
  };
  test('active statuses are blocked, not anonymized or deleted', () {
    for (final status in ['assigned', 'inProgress']) {
      expect(AccountDeletionPolicy.isActiveJob(job(status: status)), isTrue);
      expect(() => AccountDeletionPolicy.retainedJob(job(status: status), 'u'), throwsStateError);
    }
  });
  test('open, cancelled and unpaired completed jobs are removed', () {
    for (final status in ['open', 'cancelled']) { expect(AccountDeletionPolicy.retainedJob(job(status: status), 'u'), isNull); }
    expect(AccountDeletionPolicy.retainedJob(job(worker: null), 'u'), isNull);
    expect(AccountDeletionPolicy.retainedJob(job(worker: 'u'), 'u'), isNull);
  });
  test('client deletion detaches only that client and preserves counterparty accounting', () {
    final retained = AccountDeletionPolicy.retainedJob(job(), 'u')!;
    expect(retained['userId'], AccountDeletionPolicy.deletedAccount); expect(retained['workerId'], 'w');
    expect(retained['status'], 'completed'); expect(retained['budgetMax'], 2000); expect(retained['paymentStatus'], 'paid');
    expect(retained['completedAt'], job()['completedAt']);
  });
  test('worker deletion preserves the client’s completed history', () {
    final retained = AccountDeletionPolicy.retainedJob(job(), 'w')!;
    expect(retained['workerId'], AccountDeletionPolicy.deletedAccount); expect(retained['userId'], 'u');
  });
  test('replacement allowlist removes unknown legacy identifying data as well', () {
    final retained = AccountDeletionPolicy.retainedJob(job(), 'u')!;
    for (final key in ['address', 'description', 'location', 'images', 'review', 'legacyClientName', 'extra']) { expect(retained.containsKey(key), isFalse); }
    expect(retained['title'], 'Completed job'); expect(retained['anonymized'], isTrue);
  });
  test('no counterparty left means a second deletion removes the retained job', () {
    final retained = AccountDeletionPolicy.retainedJob(job(), 'u')!;
    expect(AccountDeletionPolicy.retainedJob(retained, 'w'), isNull);
  });
  test('a foreign actor cannot transform an unrelated job', () { expect(() => AccountDeletionPolicy.retainedJob(job(), 'other'), throwsArgumentError); });
  test('anonymized DTO is backward-compatible but never offers the fallback coordinate', () {
    final model = JobModel.fromMap(AccountDeletionPolicy.retainedJob(job(), 'u')!, 'j');
    expect(model.anonymized, isTrue); expect(model.hasDisclosedLocation, isFalse);
    expect(model.copyWith(title: 'History').anonymized, isTrue); expect(model.toMap()['anonymized'], isTrue);
    expect(JobModel.fromMap(job(), 'j').anonymized, isFalse);
  });
  test('receipts keep amounts/status without names, account references or actor ID', () {
    final receipt = AccountDeletionPolicy.retainedReceipt({'payerId': 'u', 'workerId': 'w', 'jobId': 'j', 'amount': 2500,
      'status': 'paid', 'method': 'mock', 'createdAt': Timestamp.now(), 'payerName': 'Ali', 'accountRef': 'secret'}, 'u');
    expect(receipt['payerId'], AccountDeletionPolicy.deletedAccount); expect(receipt['workerId'], 'w'); expect(receipt['amount'], 2500);
    expect(receipt.containsKey('payerName'), isFalse); expect(receipt.containsKey('accountRef'), isFalse);
  });
  test('receipt cleanup rejects a foreign actor and is stable for the counterparty’s deletion', () {
    final data = {'payerId': 'u', 'workerId': 'w', 'amount': 1};
    expect(() => AccountDeletionPolicy.retainedReceipt(data, 'other'), throwsArgumentError);
    final one = AccountDeletionPolicy.retainedReceipt(data, 'u'); final two = AccountDeletionPolicy.retainedReceipt(one, 'w');
    expect(two['payerId'], AccountDeletionPolicy.deletedAccount); expect(two['workerId'], AccountDeletionPolicy.deletedAccount);
  });
}
