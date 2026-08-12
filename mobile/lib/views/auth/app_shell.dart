import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/client/client_shell.dart';
import 'package:quickfix/views/worker/worker_shell.dart';

/// Root of the app after authentication. Routes to the
/// role-appropriate home screen.
///
/// When an [authService] is provided, the shells receive live user updates
/// from Firestore, so profile edits propagate without re-login.
class AppShell extends StatelessWidget {
  final UserModel user;
  final JobService? jobService;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final AuthService? authService;
  final ProfileService? profileService;

  const AppShell({
    super.key,
    required this.user,
    this.jobService,
    this.reviewService,
    this.translationService,
    this.authService,
    this.profileService,
  });

  @override
  Widget build(BuildContext context) {
    final auth = authService;
    if (auth == null) return _shellFor(user);
    return StreamBuilder<UserModel?>(
      stream: auth.watchUser(user.uid),
      builder: (context, snapshot) => _shellFor(snapshot.data ?? user),
    );
  }

  Widget _shellFor(UserModel current) {
    return switch (current.role) {
      UserRole.worker => WorkerShell(
          user: current,
          reviewService: reviewService,
          translationService: translationService,
          authService: authService,
          profileService: profileService,
        ),
      UserRole.user => ClientShell(
          user: current,
          jobService: jobService,
          reviewService: reviewService,
          translationService: translationService,
          authService: authService,
        ),
    };
  }
}