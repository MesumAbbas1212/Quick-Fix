import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/services/location_service.dart';

/// Returns true only when one-shot location access is allowed. The system
/// dialog is opened only by Allow; this screen never reads device position.
class PermissionExplainerScreen extends StatefulWidget {
  final String purpose;
  final LocationService? locationService;
  const PermissionExplainerScreen({super.key, required this.purpose, this.locationService});
  @override
  State<PermissionExplainerScreen> createState() => _PermissionExplainerScreenState();
}

class _PermissionExplainerScreenState extends State<PermissionExplainerScreen> with WidgetsBindingObserver {
  late final LocationService _locationService = widget.locationService ?? LocationService();
  LocationPermission? _status;
  bool _resolving = true;
  bool _requesting = false;
  bool _navigated = false;
  bool _settingsOpened = false;
  String? _error;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _resolveStatus(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settingsOpened && !_resolving) _resolveStatus();
  }
  bool _granted(LocationPermission status) => status == LocationPermission.always || status == LocationPermission.whileInUse;
  void _pop(bool allowed) {
    if (!mounted || _navigated) return;
    _navigated = true; Navigator.of(context).pop(allowed);
  }
  Future<void> _resolveStatus() async {
    if (_resolving && _status != null) return;
    setState(() { _resolving = true; _error = null; });
    try {
      final status = await _locationService.getPermissionStatus().timeout(const Duration(seconds: 3));
      if (!mounted) return;
      if (_granted(status)) { _pop(true); return; }
      setState(() { _status = status; _resolving = false; });
    } catch (_) {
      if (mounted) setState(() { _resolving = false; _error = 'Could not check location permission. Retry or choose Not now.'; });
    }
  }
  Future<void> _request() async {
    if (_requesting) return;
    setState(() { _requesting = true; _error = null; });
    try {
      final status = await _locationService.requestPermission().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (status == LocationPermission.deniedForever) {
        setState(() { _status = status; _requesting = false; }); return;
      }
      _pop(_granted(status));
    } catch (_) {
      if (mounted) setState(() { _requesting = false; _error = 'Could not request permission. Please try again or choose Not now.'; });
    }
  }
  Future<void> _openSettings() async {
    if (_requesting) return;
    setState(() { _requesting = true; _error = null; });
    try {
      final opened = await _locationService.openAppSettings().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() { _requesting = false; _settingsOpened = opened; });
      if (!opened) { setState(() { _error = 'Could not open app settings. You can choose Not now and continue without location.'; }); return; }
      // Settings launch may return before the app resumes. Check now and on resume.
      await _resolveStatus();
    } catch (_) {
      if (mounted) setState(() { _requesting = false; _error = 'Could not open app settings. Please try again.'; });
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Location permission'), backgroundColor: AppTheme.surfaceWhite),
    body: SafeArea(child: _resolving ? const LoadingList(rows: 2) : ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(padding: 18, child: Column(children: [
        const Icon(Icons.location_on_outlined, size: 64, color: AppTheme.brandBlue), const SizedBox(height: 16),
        Text(widget.purpose, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      ])),
      const SizedBox(height: 16),
      const AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('One position, for this action', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        SizedBox(height: 8), Text('Location helps find nearby workers, pin a job or share a position you choose in Chat. '
          'Job pins and shared positions are stored with the job or message.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        SizedBox(height: 16), Text('No background tracking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        SizedBox(height: 8), Text('QuickFix never continuously tracks you. You can browse without location and change permission in device settings.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ])),
      const SizedBox(height: 16),
      if (_error != null) ...[
        Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed)),
        TextButton(key: const Key('permission-retry'), onPressed: _requesting ? null : _resolveStatus, child: const Text('Retry permission check')),
      ],
      if (_status == LocationPermission.deniedForever) ...[
        const Text('Permission is blocked by your device. Enable it in app settings, then return here.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(height: 12), ElevatedButton(key: const Key('open-settings-button'), onPressed: _requesting ? null : _openSettings,
          child: Text(_requesting ? 'Opening…' : 'Open settings')),
      ] else ElevatedButton(key: const Key('allow-location-button'), onPressed: _requesting ? null : _request,
        child: Text(_requesting ? 'Requesting…' : 'Allow location')),
      const SizedBox(height: 10), OutlinedButton(key: const Key('not-now-button'), onPressed: () => _pop(false), child: const Text('Not now')),
    ])),
  );
}
