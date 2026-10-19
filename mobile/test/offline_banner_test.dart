import 'helpers/visible.dart' as test_viewport;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/widgets/offline_banner.dart';
import 'package:quickfix/services/network_status_service.dart';

class _MountProbe extends StatefulWidget {
  final VoidCallback onMount;
  const _MountProbe(this.onMount);
  @override
  State<_MountProbe> createState() => _MountProbeState();
}
class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() { super.initState(); widget.onMount(); }
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Last loaded job'));
}
void main() {
  late NetworkStatusService status;
  final failure = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  setUp(() { status = NetworkStatusService(); });
  tearDown(() { status.dispose(); });
  testWidgets('cached state remains mounted under a banner and recovers automatically', (tester) async {
    var mounts = 0;
    await tester.pumpWidget(MaterialApp(home: OfflineRegion(networkStatusService: status, child: _MountProbe(() { mounts++; }))));
    status.recordData(); status.recordFailure(failure); await tester.pump(); await tester.pump();
    expect(find.byType(OfflineBanner), findsOneWidget); expect(find.text('Last loaded job'), findsOneWidget); expect(mounts, 1);
    status.recordData(); await tester.pump(); await tester.pump();
    expect(find.byType(OfflineBanner), findsNothing); expect(mounts, 1);
  });
  testWidgets('cold start covers rather than removes recovery subscriptions', (tester) async {
    var mounts = 0;
    await tester.pumpWidget(MaterialApp(home: OfflineRegion(networkStatusService: status, child: _MountProbe(() { mounts++; }))));
    status.recordFailure(failure); await tester.pump(); await tester.pump();
    expect(find.byType(OfflineScreen), findsOneWidget); expect(mounts, 1);
    status.recordData(); await tester.pump(); await tester.pump();
    expect(find.byType(OfflineScreen), findsNothing); expect(mounts, 1);
  });
  testWidgets('Retry actually recreates mounted data listeners', (tester) async {
    var mounts = 0;
    await tester.pumpWidget(MaterialApp(home: OfflineRegion(networkStatusService: status, child: _MountProbe(() { mounts++; }))));
    status.recordFailure(failure); await tester.pump(); await tester.pump();
    await tester.tap(find.byKey(const Key('offline-screen-retry'))); await tester.pump(); await tester.pump();
    expect(mounts, 2); expect(status.isOffline, isTrue);
  });
  testWidgets('banner retry works independently of cold-start UI', (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OfflineBanner(onRetry: () { retries++; }))));
    await tester.tap(find.byKey(const Key('offline-banner-retry'))); expect(retries, 1);
  });
  testWidgets('cold-start copy scrolls at enlarged text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 600); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: OfflineScreen(onRetry: () {})));
    expect(tester.takeException(), isNull);
    await test_viewport.reveal(tester, find.byKey(const Key('offline-screen-retry'))); expect(find.text('Retry'), findsOneWidget);
  });
}
