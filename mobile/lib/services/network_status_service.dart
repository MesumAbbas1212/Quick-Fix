import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Inferred from Firebase data-stream failures, not a connectivity probe.
/// No timers, polling or connectivity dependency. A successful emission
/// (including a usable SDK cache snapshot) dismisses the inferred outage.
class NetworkStatusService extends ChangeNotifier {
  static final instance = NetworkStatusService();
  bool _offline = false;
  bool _hasLoadedData = false;
  bool _pendingNotification = false;
  bool _disposed = false;
  int _retryVersion = 0;
  bool get isOffline => _offline;
  bool get hasLoadedData => _hasLoadedData;
  int get retryVersion => _retryVersion;

  static bool isNetworkError(Object error) => error is FirebaseException &&
    const {'unavailable', 'deadline-exceeded', 'network-request-failed'}.contains(error.code);
  void _changed() {
    if (_pendingNotification || _disposed) return;
    _pendingNotification = true;
    scheduleMicrotask(() {
      _pendingNotification = false;
      if (!_disposed) notifyListeners();
    });
  }
  void recordData() {
    final changed = _offline || !_hasLoadedData;
    _offline = false; _hasLoadedData = true;
    if (changed) _changed();
  }
  void recordFailure(Object error) {
    if (!isNetworkError(error) || _offline) return;
    _offline = true; _changed();
  }
  /// Consumers key their mounted subscriptions to this value. Retry does not
  /// optimistically pretend that a network request has succeeded.
  void retry() { _retryVersion++; _changed(); }
  void reset() { _offline = false; _hasLoadedData = false; _retryVersion++; _changed(); }

  Stream<T> observe<T>(Stream<T> source) => Stream<T>.multi((sink) {
    var received = false;
    final subscription = source.listen((data) {
      received = true; recordData(); sink.add(data);
    }, onError: (Object error, StackTrace stack) {
      recordFailure(error);
      // Keep StreamBuilder's last usable snapshot on network loss. Do not
      // conceal permission, validation or model errors behind an offline label.
      if (!received || !isNetworkError(error)) sink.addError(error, stack);
    }, onDone: sink.close);
    sink.onCancel = subscription.cancel;
    sink.onPause = subscription.pause;
    sink.onResume = subscription.resume;
  });
  @override
  void dispose() { _disposed = true; super.dispose(); }
}

extension ObservedFirebaseStream<T> on Stream<T> {
  Stream<T> trackNetwork({NetworkStatusService? status}) => (status ?? NetworkStatusService.instance).observe(this);
}
