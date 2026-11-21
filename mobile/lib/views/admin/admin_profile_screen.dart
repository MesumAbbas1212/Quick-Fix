import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
class AdminProfileScreen extends StatelessWidget {
  final UserModel user; final AuthService? authService;
  const AdminProfileScreen({super.key, required this.user, this.authService});
  @override Widget build(BuildContext context) => const Center(child: Text('Profile'));
}
