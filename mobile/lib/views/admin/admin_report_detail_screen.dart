import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
class AdminReportDetailScreen extends StatelessWidget {
  final String reportId; final UserModel user; final AdminService? adminService;
  const AdminReportDetailScreen({super.key, required this.reportId, required this.user, this.adminService});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Report review')));
}
