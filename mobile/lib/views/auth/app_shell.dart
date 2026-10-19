import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/views/settings/delete_account_screen.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'package:quickfix/views/auth/force_update_screen.dart';
import 'package:quickfix/services/network_status_service.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
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
  final LocationService? locationService;
  final AccountDeletionService? accountDeletionService;
  final AppReleaseService? releaseService;
  final NetworkStatusService? networkStatusService;
  final JobService? jobService;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final AuthService? authService;
  final ProfileService? profileService;
  final ChatService? chatService;

  const AppShell({
    super.key,
    required this.user,
    this.locationService,
    this.accountDeletionService,
    this.releaseService,
    this.networkStatusService,
    this.jobService,
    this.reviewService,
    this.translationService,
    this.authService,
    this.profileService,
    this.chatService,
  });

  @override
  Widget build(BuildContext context) => AppReleaseGate(releaseService: releaseService, child: _content());

  Widget _content() {
    if (user.deletionPending) return DeleteAccountScreen(user: user, authService: authService, accountDeletionService: accountDeletionService);
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
          networkStatusService: networkStatusService,
          reviewService: reviewService,
          translationService: translationService,
          authService: authService,
          profileService: profileService,
          jobService: jobService,
          chatService: chatService,
        ),
      // Admins use the client shell on mobile (the React dashboard is the
      // primary admin surface); they explicitly map to a valid shell instead
      // of silently falling back after a role parse failure.
      UserRole.user || UserRole.admin => ClientShell(
          user: current,
      locationService: locationService,
          networkStatusService: networkStatusService,
          jobService: jobService,
          reviewService: reviewService,
          translationService: translationService,
          authService: authService,
          profileService: profileService,
          chatService: chatService,
        ),
    };
  }
}