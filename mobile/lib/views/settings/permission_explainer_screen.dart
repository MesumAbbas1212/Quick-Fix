import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/location_service.dart';

/// In-app explanation shown **before** the system location dialog, so the
/// user knows why the app asks, what data is used, and what the app never
/// does (no background or continuous tracking — one-shot fixes only).
///
/// Returns a `bool` via `Navigator.pop`:
/// - `true`  — location is (now) allowed; the caller may proceed.
/// - `false` — the user chose "Not now"; the caller must degrade gracefully.
class PermissionExplainerScreen extends StatefulWidget {
  /// Why the app needs the location right now (one line, specific to the
  /// call site): e.g. "to show nearby workers".
  final String purpose;

  final LocationService? locationService;

  const PermissionExplainerScreen({
    super.key,
    required this.purpose,
    this.locationService,
  });

  @override
  State<PermissionExplainerScreen> createState() =>
      _PermissionExplainerScreenState();
}

class _PermissionExplainerScreenState extends State<PermissionExplainerScreen> {
  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  LocationPermission? _status;
  bool _resolving = true;
  bool _requesting = false;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _resolveStatus();
  }

  Future<void> _resolveStatus() async {
    LocationPermission status;
    try {
      status = await _locationService.getPermissionStatus();
    } catch (_) {
      // Permission API unavailable (e.g. platform channel not ready) —
      // fall through to the explainer; the request attempt will decide.
      status = LocationPermission.denied;
    }
    if (!mounted) return;
    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      // Already granted — no explainer needed.
      _pop(true);
      return;
    }
    setState(() {
      _status = status;
      _resolving = false;
    });
  }

  void _pop(bool allowed) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pop(allowed);
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      final status = await _locationService.requestPermission();
      final granted =
          status == LocationPermission.always ||
              status == LocationPermission.whileInUse;
      _pop(granted);
    } catch (_) {
      _pop(false);
    }
  }

  Future<void> _openSettings() async {
    try {
      await _locationService.openAppSettings();
    } catch (_) {
      // No settings app available — nothing else we can do.
    }
    // Re-check on return from settings.
    await _resolveStatus();
  }

  bool get _deniedForever => _status == LocationPermission.deniedForever;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Location permission',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _resolving
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.brandBlue,
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: AppTheme.borderGray),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 48,
                            color: AppTheme.brandBlue,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.purpose,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _infoCard('What we use it for',
                        'Your position is used once, for this action — to '
                        'find nearby workers, pin your job, or share a '
                        'location in chat.'),
                    const SizedBox(height: 10),
                    _infoCard('What we never do',
                        'We never track you in the background and never '
                        'store a history of your movements. No continuous '
                        'location, ever.'),
                    const Spacer(),
                    if (_deniedForever) ...[
                      _primaryButton(
                        label: 'Open settings',
                        key: const Key('open-settings-button'),
                        onPressed: _openSettings,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _primaryButton(
                      label: 'Allow location',
                      key: const Key('allow-location-button'),
                      onPressed: _requesting ? null : _request,
                      child: _requesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: const Key('not-now-button'),
                      onPressed: () => _pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        side: const BorderSide(color: AppTheme.borderGray),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Not now',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _infoCard(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required Key key,
    required VoidCallback? onPressed,
    Widget? child,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        key: key,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.ctaOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            child ??
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
      ),
    );
  }
}
