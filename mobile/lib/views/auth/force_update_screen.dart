import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/services/app_release_service.dart';

class ForceUpdateScreen extends StatefulWidget {
  final AppReleaseConfig config;
  final int currentBuild;
  final AppReleaseService? releaseService;
  final VoidCallback? onRetry;
  const ForceUpdateScreen({super.key, required this.config, this.currentBuild = AppReleaseService.currentBuildNumber,
    this.releaseService, this.onRetry});
  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}
class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  late final AppReleaseService _service = widget.releaseService ?? AppReleaseService();
  bool _opening = false;
  String? _error;
  Future<void> _update() async {
    if (_opening) { return; }
    setState(() { _opening = true; _error = null; });
    try {
      final opened = await _service.openStore(widget.config.storeUrl).timeout(const Duration(seconds: 8));
      if (!opened) { throw StateError('Store unavailable'); }
    } catch (_) {
      if (mounted) { setState(() { _error = 'Could not open the app store. Check your connection, then try Update now again.'; }); }
    } finally { if (mounted) { setState(() { _opening = false; }); } }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: false, child: Scaffold(
    backgroundColor: AppTheme.bgLight,
    appBar: AppBar(automaticallyImplyLeading: false, title: const Text('QuickFix')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 24), const Icon(Icons.system_update_outlined, size: 72, color: AppTheme.brandBlue),
      const SizedBox(height: 20), const Text('Update required', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
      const SizedBox(height: 16), AppCard(child: Text(widget.config.message, style: const TextStyle(fontSize: 14))),
      const SizedBox(height: 16), Text('Installed build ${widget.currentBuild} • Minimum ${widget.config.minBuild} • Latest ${widget.config.latestBuild}',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
      const SizedBox(height: 24), ElevatedButton(key: const Key('force-update-now'), onPressed: _opening ? null : _update,
        child: Text(_opening ? 'Opening store…' : 'Update now')),
      if (widget.onRetry != null) TextButton(key: const Key('force-update-recheck'), onPressed: _opening ? null : widget.onRetry, child: const Text('Check again after updating')),
    ])),
  ));
}

/// Also wraps AppShell, so direct post-sign-in/sign-up entry cannot bypass a
/// successful minBuild check. Missing/failed config is intentionally fail-open.
class AppReleaseGate extends StatefulWidget {
  final Widget child;
  final AppReleaseService? releaseService;
  const AppReleaseGate({super.key, required this.child, this.releaseService});
  @override
  State<AppReleaseGate> createState() => _AppReleaseGateState();
}
class _AppReleaseGateState extends State<AppReleaseGate> {
  late final AppReleaseService _service = widget.releaseService ?? AppReleaseService();
  late Future<AppReleaseDecision> _check = _load();
  Future<AppReleaseDecision> _load() async {
    try { return await _service.checkForUpdate().timeout(const Duration(seconds: 6)); }
    catch (_) { return const AppReleaseDecision(currentBuild: AppReleaseService.currentBuildNumber); }
  }
  void _retry() { setState(() { _check = _load(); }); }
  @override
  Widget build(BuildContext context) => FutureBuilder<AppReleaseDecision>(future: _check, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) { return const Scaffold(backgroundColor: AppTheme.bgLight,
      body: SafeArea(child: LoadingList(rows: 3))); }
    final decision = snapshot.data;
    if (decision != null && decision.requiresUpdate) { return ForceUpdateScreen(config: decision.config!, currentBuild: decision.currentBuild,
      releaseService: _service, onRetry: _retry); }
    // latestBuild alone never gates the interface or starts a blocking dialog.
    return widget.child;
  });
}
