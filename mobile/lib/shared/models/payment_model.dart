import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String jobId;
  final String payerId;
  final String workerId;
  final double amount;
  final String status;
  final String method;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.jobId,
    required this.payerId,
    required this.workerId,
    required this.amount,
    this.status = 'pending',
    this.method = 'mock',
    required this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map, String id) {
    return Payment(
      id: id,
      jobId: map['jobId'] ?? '',
      payerId: map['payerId'] ?? '',
      workerId: map['workerId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] ?? 'pending',
      method: map['method'] ?? 'mock',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'payerId': payerId,
      'workerId': workerId,
      'amount': amount,
      'status': status,
      'method': method,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
