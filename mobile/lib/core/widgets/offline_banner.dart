import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/network_status_service.dart';

class OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const OfflineBanner({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Material(color: AppTheme.accentYellow, child: Padding(
    padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 4, bottom: 4),
    child: Row(children: [const Icon(Icons.cloud_off_outlined, size: 20, color: AppTheme.textDark),
      const SizedBox(width: 8), const Expanded(child: Text('You’re offline — showing the last loaded data',
        style: TextStyle(fontSize: 13, color: AppTheme.textDark))),
      TextButton(style: TextButton.styleFrom(foregroundColor: AppTheme.textDark),
        key: const Key('offline-banner-retry'), onPressed: onRetry, child: const Text('Retry')),
    ]),
  ));
}

/// The cold-start version, also used for a failed initial profile read.
class OfflineScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const OfflineScreen({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(automaticallyImplyLeading: false, title: const Text('QuickFix')),
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: BoxConstraints(minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity).toDouble()),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_outlined, size: 72, color: AppTheme.brandBlue), const SizedBox(height: 20),
          const Text('Connection unavailable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12), const Text('There is no loaded data to show yet. Restore your connection and try again.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          const SizedBox(height: 24), ElevatedButton(key: const Key('offline-screen-retry'), onPressed: onRetry, child: const Text('Retry')),
        ])),
    ))),
  );
}

/// Never unmount the cold-start child just because it is offline: its mounted
/// subscriptions must remain able to deliver the successful recovery event.
/// Only an explicit Retry recreates the child's listeners.
class OfflineRegion extends StatelessWidget {
  final Widget child;
  final NetworkStatusService? networkStatusService;
  final VoidCallback? onRetry;
  const OfflineRegion({super.key, required this.child, this.networkStatusService, this.onRetry});
  @override
  Widget build(BuildContext context) {
    final status = networkStatusService ?? NetworkStatusService.instance;
    void retry() { status.retry(); onRetry?.call(); }
    return AnimatedBuilder(animation: status, builder: (context, _) => Stack(children: [
      KeyedSubtree(key: ValueKey(status.retryVersion), child: child),
      if (status.isOffline && !status.hasLoadedData) Positioned.fill(child: OfflineScreen(onRetry: retry)),
      if (status.isOffline && status.hasLoadedData) PositionedDirectional(top: 0, start: 0, end: 0,
        child: SafeArea(bottom: false, child: OfflineBanner(onRetry: retry))),
    ]));
  }
}
