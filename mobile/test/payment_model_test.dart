import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/payment_model.dart';

void main() {
  group('Payment', () {
    test('fromMap round-trips all fields', () {
      final map = {
        'jobId': 'job1',
        'payerId': 'user1',
        'workerId': 'worker1',
        'amount': 2500.0,
        'status': 'paid',
        'method': 'mock',
        'createdAt': Timestamp.fromDate(DateTime(2024, 6, 1, 10, 0)),
      };

      final payment = Payment.fromMap(map, 'pay1');

      expect(payment.id, 'pay1');
      expect(payment.jobId, 'job1');
      expect(payment.payerId, 'user1');
      expect(payment.workerId, 'worker1');
      expect(payment.amount, 2500.0);
      expect(payment.status, 'paid');
      expect(payment.method, 'mock');
      expect(payment.createdAt, DateTime(2024, 6, 1, 10, 0));
    });

    test('defaults status to pending when missing', () {
      final map = {
        'jobId': 'job1',
        'payerId': 'user1',
        'workerId': 'worker1',
        'amount': 1000.0,
      };

      final payment = Payment.fromMap(map, 'pay2');

      expect(payment.status, 'pending');
      expect(payment.method, 'mock');
    });

    test('toMap serializes with paid status', () {
      final payment = Payment(
        id: 'pay1',
        jobId: 'job1',
        payerId: 'user1',
        workerId: 'worker1',
        amount: 3500.0,
        status: 'paid',
        createdAt: DateTime(2024, 6, 1),
      );

      final map = payment.toMap();

      expect(map['jobId'], 'job1');
      expect(map['amount'], 3500.0);
      expect(map['status'], 'paid');
      expect(map['createdAt'], isA<Timestamp>());
    });
  });
}
