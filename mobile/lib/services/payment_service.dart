import 'package:quickfix/services/notification_service.dart';
import 'package:quickfix/services/network_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore;
  final NetworkStatusService _network;

  PaymentService({FirebaseFirestore? firestore, NetworkStatusService? networkStatusService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _network = networkStatusService ?? NetworkStatusService.instance;

  Future<List<Payment>> getWorkerPaymentsServer(String uid) async {
    final snapshot = await _paymentsCollection.where('workerId', isEqualTo: uid).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 10));
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) throw StateError('Waiting for confirmed receipts.');
    return snapshot.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
  }

  Future<Payment?> getPayment(String id) async {
    final snapshot = await _firestore.collection('payments').doc(id).get().timeout(const Duration(seconds: 8));
    return snapshot.exists ? Payment.fromMap(snapshot.data()!, snapshot.id) : null;
  }

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      _firestore.collection('payments');

  /// Simulates a payment with a fake 1.5s processing delay, then writes a
  /// `payments/{id}` doc with status 'paid'.
  Future<Payment> simulatePayment({
    required String jobId,
    required String payerId,
    required String workerId,
    required double amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final payment = Payment(
      id: '',
      jobId: jobId,
      payerId: payerId,
      workerId: workerId,
      amount: amount,
      status: 'paid',
      createdAt: DateTime.now(),
    );

    final docRef = await _paymentsCollection.add(payment.toMap());
    await _firestore.collection('jobs').doc(jobId).update({
      'paymentStatus': 'paid',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    NotificationService(firestore: _firestore).sendBestEffort(userId: workerId, type: 'payment', refId: docRef.id,
      title: 'Simulated payment recorded', body: 'A receipt was added to your payment history. No real funds moved.');
    return Payment(
      id: docRef.id,
      jobId: payment.jobId,
      payerId: payment.payerId,
      workerId: payment.workerId,
      amount: payment.amount,
      status: payment.status,
      createdAt: payment.createdAt,
    );
  }

  Future<List<Payment>> getPaymentsForJob(String jobId) async {
    final snap = await _paymentsCollection
        .where('jobId', isEqualTo: jobId)
        .get();
    final payments =
        snap.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payments;
  }

  /// The job's first paid record, or null — the never-charge-twice guard
  /// for the payment screen.
  Future<Payment?> getPaidPaymentForJob(String jobId) async {
    final payments = await getPaymentsForJob(jobId);
    for (final p in payments) {
      if (p.status == 'paid') return p;
    }
    return null;
  }

  /// Live receipts for a client: payments they made, newest first.
  Stream<List<Payment>> watchPaymentsByPayer(String payerId) {
    return _paymentsCollection
        .where('payerId', isEqualTo: payerId)
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) {
          final payments =
              snapshot.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
          payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return payments;
        });
  }

  /// Live income for a worker: payments made to them, newest first.
  Stream<List<Payment>> watchPaymentsByWorker(String workerId) {
    return _paymentsCollection
        .where('workerId', isEqualTo: workerId)
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) {
          final payments =
              snapshot.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
          payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return payments;
        });
  }
}
