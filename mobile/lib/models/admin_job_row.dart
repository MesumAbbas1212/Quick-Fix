import 'package:cloud_firestore/cloud_firestore.dart';

class AdminJobRow {
  final String id;
  final String title;
  final String category;
  final String status;
  final double budgetMin;
  final double budgetMax;
  final String address;
  final String clientName;
  final String? workerName;
  final DateTime createdAt;
  final String clientId;
  final String? workerId;
  final DateTime? preferredDate;
  final DateTime? preferredTime;

  const AdminJobRow({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.budgetMin,
    required this.budgetMax,
    required this.address,
    required this.clientName,
    this.workerName,
    required this.createdAt,
    this.clientId = '',
    this.workerId,
    this.preferredDate,
    this.preferredTime,
  });

  factory AdminJobRow.fromMap(
    String id,
    Map<String, dynamic> data, {
    required String clientName,
    String? workerName,
  }) => AdminJobRow(
    id: id,
    title: (data['title'] ?? '').toString(),
    category: (data['category'] ?? 'other').toString(),
    status: (data['status'] ?? 'open').toString(),
    budgetMin: _number(data['budgetMin']),
    budgetMax: _number(data['budgetMax']),
    address: (data['address'] ?? '').toString(),
    clientName: clientName,
    workerName: workerName,
    createdAt: _date(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    clientId: (data['userId'] ?? '').toString(),
    workerId: _optionalString(data['workerId']),
    preferredDate: _date(data['preferredDate']),
    preferredTime: _date(data['preferredTime']),
  );

  static String? _optionalString(Object? value) {
    final string = value?.toString().trim();
    return string == null || string.isEmpty ? null : string;
  }

  static double _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}
