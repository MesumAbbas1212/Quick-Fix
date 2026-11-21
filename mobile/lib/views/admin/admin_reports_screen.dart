import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/auth_service.dart';
class AdminReportsScreen extends StatelessWidget {
  final UserModel user; final AuthService? authService; final AdminService? adminService;
  const AdminReportsScreen({super.key, required this.user, this.authService, this.adminService});
  @override Widget build(BuildContext context) => const Center(child: Text('Reports'));
}
