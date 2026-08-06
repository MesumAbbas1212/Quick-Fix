import 'package:flutter/material.dart';
import 'package:quickfix/features/auth/presentation/auth_screens.dart';
import 'package:quickfix/features/jobs/presentation/find_jobs_screen.dart';
import 'package:quickfix/features/jobs/presentation/worker_dashboard_screen.dart';
import 'package:quickfix/shared/models/user_model.dart';

/// Root of the app after authentication. Routes to the
/// role-appropriate home screen.
class AppShell extends StatelessWidget {
  final UserModel user;

  const AppShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return switch (user.role) {
      UserRole.worker => WorkerDashboardScreen(user: user),
      UserRole.user => FindJobsScreen(user: user),
    };
  }
}
