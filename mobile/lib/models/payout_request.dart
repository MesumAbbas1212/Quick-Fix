import 'package:cloud_firestore/cloud_firestore.dart';
class PayoutRequest {
  final String id, workerId, method, accountRef, status;
  final int amountPaisa;
  final DateTime? createdAt;
  const PayoutRequest({required this.id, required this.workerId, required this.amountPaisa, required this.method, required this.accountRef, required this.status, this.createdAt});
  factory PayoutRequest.fromMap(Map<String, dynamic> data, String id) => PayoutRequest(id: id, workerId: data['workerId'] as String? ?? '',
    amountPaisa: data['amountPaisa'] is int ? data['amountPaisa'] as int : (((data['amount'] as num?)?.toDouble() ?? 0) * 100).round(),
    method: data['method'] as String? ?? '', accountRef: data['accountRef'] as String? ?? '', status: data['status'] as String? ?? 'pending', createdAt: (data['createdAt'] as Timestamp?)?.toDate());
  bool get reserves => const {'pending', 'approved', 'processing', 'paid'}.contains(status);
}
class PayoutSnapshot {
  final int receivedPaisa, reservedPaisa, revision;
  final String method, accountRef;
  final List<PayoutRequest> history;
  const PayoutSnapshot({required this.receivedPaisa, required this.reservedPaisa, required this.revision, this.method = 'jazzcash', this.accountRef = '', this.history = const []});
  int get availablePaisa => receivedPaisa > reservedPaisa ? receivedPaisa - reservedPaisa : 0;
}
