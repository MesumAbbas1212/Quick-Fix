import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/models/payout_request.dart';
import 'package:quickfix/services/payment_service.dart';
class _PayoutSnapshotChanged implements Exception {}
class PayoutService {
  final FirebaseFirestore? _injectedFirestore;
  final PaymentService? _injectedPayments;
  PayoutService({FirebaseFirestore? firestore, PaymentService? paymentService}) : _injectedFirestore = firestore, _injectedPayments = paymentService;
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  late final PaymentService _payments = _injectedPayments ?? PaymentService(firestore: _firestore);
  DocumentReference<Map<String, dynamic>> _state(String uid) => _firestore.collection('workers').doc(uid).collection('private').doc('payout');
  String newRequestId() => _firestore.collection('payouts').doc().id;
  static const methods = ['jazzcash', 'easypaisa', 'bank'];
  static int? parsePaisa(String text) {
    final value = text.trim(); if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value)) return null;
    final pieces = value.split('.'); final whole = int.tryParse(pieces.first); final decimal = pieces.length == 1 ? 0 : int.parse(pieces[1].padRight(2, '0'));
    if (whole == null || whole > 90071992547409) return null; final result = whole * 100 + decimal; return result > 9007199254740991 ? null : result;
  }
  static int receivedPaisa(String uid, Iterable<Payment> payments) {
    var sum = 0;
    for (final payment in payments.where((payment) => payment.workerId == uid && payment.status == 'paid' && !payment.createdAt.isAfter(DateTime.now()))) {
      if (!payment.amount.isFinite || payment.amount < 0 || payment.amount * 100 > 9007199254740991) throw const FormatException('Receipt amount needs operator review.');
      sum += (payment.amount * 100).round();
    }
    if (sum > 9007199254740991) throw const FormatException('Balance exceeds supported safe precision.');
    return sum;
  }
  static int reservedPaisa(Iterable<PayoutRequest> requests) => requests.where((request) => request.reserves).fold(0, (sum, request) {
    if (request.amountPaisa <= 0) throw const FormatException('Payout amount needs review.'); return sum + request.amountPaisa;
  });
  Future<PayoutSnapshot> load(String uid) async {
    await _firestore.waitForPendingWrites().timeout(const Duration(seconds: 8));
    final state = (await _state(uid).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 8))).data() ?? {};
    final payments = await _payments.getWorkerPaymentsServer(uid);
    final payouts = await _firestore.collection('payouts').where('workerId', isEqualTo: uid).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 10));
    if (payouts.metadata.isFromCache || payouts.metadata.hasPendingWrites) throw StateError('Waiting for confirmed payout history.');
    final history = payouts.docs.map((doc) => PayoutRequest.fromMap(doc.data(), doc.id)).toList()..sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
    return PayoutSnapshot(receivedPaisa: receivedPaisa(uid, payments), reservedPaisa: reservedPaisa(history), revision: state['revision'] as int? ?? 0,
      method: state['method'] as String? ?? 'jazzcash', accountRef: state['accountRef'] as String? ?? '', history: history);
  }
  Future<PayoutRequest> request({required String uid, required String requestId, required int amountPaisa, required String method, required String accountRef}) async {
    if (amountPaisa <= 0 || amountPaisa > 9007199254740991 || !methods.contains(method) || !RegExp(r'^[A-Za-z0-9 +_-]{3,64}$').hasMatch(accountRef.trim())) throw ArgumentError('Check amount, method and demo account reference.');
    final reference = _firestore.collection('payouts').doc(requestId);
    for (var attempt = 0; attempt < 3; attempt++) {
      final previous = await reference.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 8));
      if (previous.exists) { if (previous.data()?['workerId'] != uid) throw StateError('Foreign request.'); return PayoutRequest.fromMap(previous.data()!, previous.id); }
      final snapshot = await load(uid);
      if (amountPaisa > snapshot.availablePaisa) throw ArgumentError('Amount exceeds the confirmed available balance.');
      try {
        return await _firestore.runTransaction<PayoutRequest>((transaction) async {
          final stateRef = _state(uid); final state = await transaction.get(stateRef); final existing = await transaction.get(reference);
          if (existing.exists) { if (existing.data()?['workerId'] != uid) throw StateError('Foreign request.'); return PayoutRequest.fromMap(existing.data()!, existing.id); }
          if ((state.data()?['revision'] as int? ?? 0) != snapshot.revision) throw _PayoutSnapshotChanged();
          transaction.set(reference, {'workerId': uid, 'amount': amountPaisa / 100, 'amountPaisa': amountPaisa, 'method': method, 'accountRef': accountRef.trim(), 'status': 'pending', 'createdAt': FieldValue.serverTimestamp()});
          transaction.set(stateRef, {'revision': snapshot.revision + 1, 'lastPayoutId': requestId, 'method': method, 'accountRef': accountRef.trim()});
          transaction.update(_firestore.collection('workers').doc(uid), {'payoutMethod': {'type': method}});
          return PayoutRequest(id: requestId, workerId: uid, amountPaisa: amountPaisa, method: method, accountRef: accountRef.trim(), status: 'pending');
        }).timeout(const Duration(seconds: 12));
      } on _PayoutSnapshotChanged { if (attempt == 2) rethrow; }
    }
    throw StateError('Payout state changed. Refresh before retrying.');
  }
}
