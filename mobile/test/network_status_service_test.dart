import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/network_status_service.dart';

void main() {
  late NetworkStatusService status;
  final offline = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  setUp(() { status = NetworkStatusService(); });
  tearDown(() { status.dispose(); });
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  test('a fresh monitor has no loaded data and does not guess that it is offline', () {
    expect(status.isOffline, isFalse); expect(status.hasLoadedData, isFalse);
  });
  test('only transport-like Firebase failures are classified as offline', () {
    for (final code in ['unavailable', 'deadline-exceeded', 'network-request-failed']) {
      expect(NetworkStatusService.isNetworkError(FirebaseException(plugin: 'test', code: code)), isTrue);
    }
    for (final code in ['permission-denied', 'unauthenticated', 'resource-exhausted', 'invalid-argument']) {
      expect(NetworkStatusService.isNetworkError(FirebaseException(plugin: 'test', code: code)), isFalse);
    }
    expect(NetworkStatusService.isNetworkError(StateError('bad model')), isFalse);
  });
  test('a first network error is forwarded and selects the cold-start state', () async {
    final errors = <Object>[];
    await status.observe(Stream<int>.error(offline)).listen((_) {}, onError: errors.add).asFuture<void>().catchError((_) {});
    expect(status.isOffline, isTrue); expect(status.hasLoadedData, isFalse);
  });
  test('loaded data survives a network failure without an error snapshot', () async {
    final source = StreamController<int>(); final data = <int>[]; final errors = <Object>[];
    final sub = status.observe(source.stream).listen(data.add, onError: errors.add);
    source.add(9); await flush(); source.addError(offline); await flush();
    expect(data, [9]); expect(errors, isEmpty); expect(status.isOffline, isTrue); expect(status.hasLoadedData, isTrue);
    source.add(10); await flush(); expect(status.isOffline, isFalse); expect(data, [9, 10]);
    await sub.cancel(); await source.close();
  });
  test('permission errors are never hidden even after a successful snapshot', () async {
    final source = StreamController<int>(); final errors = <Object>[];
    final sub = status.observe(source.stream).listen((_) {}, onError: errors.add);
    source.add(1); await flush(); source.addError(FirebaseException(plugin: 'test', code: 'permission-denied')); await flush();
    expect(errors, hasLength(1)); expect(status.isOffline, isFalse);
    await sub.cancel(); await source.close();
  });
  test('retry advances the subscription revision without claiming recovery', () {
    status.recordFailure(offline); status.retry(); expect(status.retryVersion, 1); expect(status.isOffline, isTrue);
  });
  test('reset removes account-scoped state', () {
    status.recordData(); status.recordFailure(offline); status.reset();
    expect(status.hasLoadedData, isFalse); expect(status.isOffline, isFalse); expect(status.retryVersion, 1);
  });
  test('cancel propagates to the underlying listener', () async {
    var cancelled = false; final source = StreamController<int>(onCancel: () { cancelled = true; });
    final sub = status.observe(source.stream).listen((_) {});
    await sub.cancel(); expect(cancelled, isTrue); await source.close();
  });
}
