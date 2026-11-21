import 'package:quickfix/models/admin_account_row.dart';

class AdminAccountDetail {
  final AdminAccountRow account;
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? workerData;
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> reviews;
  final Map<String, dynamic>? verification;
  const AdminAccountDetail({required this.account, required this.userData, this.workerData, this.jobs = const [], this.reviews = const [], this.verification});
}
