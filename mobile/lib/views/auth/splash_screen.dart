import 'package:quickfix/core/widgets/offline_banner.dart';
import 'package:quickfix/services/network_status_service.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/preferences_service.dart';
import 'package:quickfix/views/onboarding/onboarding_carousel.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/auth/login_screen.dart';

/// Bootstrap screen: resolves the Firebase auth state and the user's profile,
/// then routes a signed-in user straight to their shell (skipping login) or
/// an unsigned user to the login screen.
///
/// A hard timeout guarantees the splash never spins forever: if the auth
/// state or the profile read does not resolve in time, the user lands on the
/// login screen with an explanatory snackbar instead of an infinite loader.
class SplashScreen extends StatefulWidget {
  final AuthService? authService;
  final PreferencesService? preferencesService;

  /// Hard upper bound for resolving auth + profile. Injectable for tests.
  final Duration resolveTimeout;

  const SplashScreen({
    super.key,
    this.authService,
    this.preferencesService,
    this.resolveTimeout = const Duration(seconds: 5),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;
  Timer? _timeout;
  StreamSubscription<User?>? _authSub;

  late final AuthService _auth = widget.authService ?? AuthService();
  late final PreferencesService _preferences = widget.preferencesService ?? PreferencesService();
  bool _showOnboarding = false;
  bool _authStarted = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var seen = true;
    try { seen = await _preferences.hasSeenOnboarding().timeout(const Duration(seconds: 1)); }
    catch (_) { /* An unavailable preference store must never trap launch. */ }
    if (!mounted || _navigated) return;
    if (!seen) { setState(() { _showOnboarding = true; }); return; }
    _startAuth();
  }

  void _startAuth() {
    if (!mounted || _authStarted || _navigated) return;
    _authStarted = true;
    setState(() { _showOnboarding = false; });
    _timeout = Timer(widget.resolveTimeout, _fallbackToLogin);
    try {
      _authSub = _auth.authStateChanges.listen(_onAuth, onError: _resolutionError);
    } catch (error) { _resolutionError(error); }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _routeTo(Widget page) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timeout?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  bool _resolvingProfile = false;
  Future<void> _onAuth(User? user) async {
    if (_navigated || !mounted || _resolvingProfile) return;
    if (user == null) { _routeTo(const LoginScreen()); return; }
    _resolvingProfile = true;
    try {
      final profile = await _auth.getUserProfile(user.uid);
      if (profile == null) { _fallbackToLogin(); return; }
      _routeTo(AppShell(user: profile, authService: widget.authService));
    } catch (error) { _resolutionError(error); }
  }

  void _resolutionError(Object error) {
    if (_navigated || !mounted) return;
    if (!NetworkStatusService.isNetworkError(error)) { _fallbackToLogin(); return; }
    final navigator = Navigator.of(context);
    final auth = _auth;
    final preferences = _preferences;
    final timeout = widget.resolveTimeout;
    _routeTo(OfflineScreen(onRetry: () {
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => SplashScreen(
        authService: auth, preferencesService: preferences, resolveTimeout: timeout)));
    }));
  }

  /// Timeout / error path: always land somewhere real, never on a spinner.
  void _fallbackToLogin() {
    if (_navigated) return;
    _routeTo(const _LoginWithNote(
      showNote: true,
      message: "Couldn't load your profile. Please sign in again.",
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) return OnboardingCarousel(preferencesService: _preferences, onFinished: _startAuth);
    return Scaffold(
      backgroundColor: AppTheme.brandBlue,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppTheme.accentYellow,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Q',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brandBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'QuickFix',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.surfaceWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Find skilled professionals near you.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.surfaceWhite.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.surfaceWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Login screen that shows a one-time snackbar (e.g. when the splash timed
/// out or the profile read failed), so the fallback is never silent.
class _LoginWithNote extends StatefulWidget {
  final bool showNote;
  final String message;

  const _LoginWithNote({required this.showNote, required this.message});

  @override
  State<_LoginWithNote> createState() => _LoginWithNoteState();
}

class _LoginWithNoteState extends State<_LoginWithNote> {
  @override
  void initState() {
    super.initState();
    if (widget.showNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => const LoginScreen();
}
