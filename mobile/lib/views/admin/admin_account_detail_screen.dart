import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
class AdminAccountDetailScreen extends StatelessWidget {
  final String uid; final bool worker; final UserModel user; final AdminService? adminService;
  const AdminAccountDetailScreen({super.key, required this.uid, this.worker = false, required this.user, this.adminService});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Account review')));
}
