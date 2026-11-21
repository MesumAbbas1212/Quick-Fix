import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/auth_service.dart';
class AdminDashboardScreen extends StatelessWidget {
  final UserModel user; final AuthService? authService; final AdminService? adminService;
  final VoidCallback? onOpenReports; final VoidCallback? onOpenAccounts;
  const AdminDashboardScreen({super.key, required this.user, this.authService, this.adminService, this.onOpenReports, this.onOpenAccounts});
  @override Widget build(BuildContext context) => const Center(child: Text('Overview'));
}
