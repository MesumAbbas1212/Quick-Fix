import 'package:flutter/material.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/client/client_shell.dart';
import 'package:quickfix/views/worker/worker_shell.dart';
import 'package:quickfix/models/user_model.dart';

/// Root of the app after authentication. Routes to the
/// role-appropriate home screen.
class AppShell extends StatelessWidget {
  final UserModel user;
  final JobService? jobService;

  const AppShell({super.key, required this.user, this.jobService});

  @override
  Widget build(BuildContext context) {
    return switch (user.role) {
      UserRole.worker => WorkerShell(user: user),
      UserRole.user => ClientShell(user: user, jobService: jobService),
    };
  }
}
