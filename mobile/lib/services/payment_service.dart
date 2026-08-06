import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/shared/models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    final docRef = await _firestore.collection('payments').add(payment.toMap());
    await _firestore.collection('jobs').doc(jobId).update({
      'paymentStatus': 'paid',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

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
    final snap = await _firestore
        .collection('payments')
        .where('jobId', isEqualTo: jobId)
        .get();
    return snap.docs
        .map((doc) => Payment.fromMap(doc.data(), doc.id))
        .toList();
  }
}