import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/services/location_provider.dart';

/// Fetches the user's real GPS position on explicit request only.
/// There is NO background tracking anywhere in this class.
class LocationService {
  final LocationProvider _provider;

  LocationService({LocationProvider? provider})
      : _provider = provider ?? const DeviceLocationProvider();

  static double? distanceKm(GeoPoint? from, GeoPoint? to) {
    if (from == null || to == null) return null;
    return Geolocator.distanceBetween(from.latitude, from.longitude, to.latitude, to.longitude) / 1000;
  }

  /// Current fine-location permission status, without requesting it.
  /// Used by the permission explainer to decide what to show.
  Future<LocationPermission> getPermissionStatus() =>
      _provider.checkPermission();

  /// Shows the system permission dialog (if needed) and returns the
  /// resulting status. Call this from the permission explainer's "Allow"
  /// button so the user always sees our in-app explanation first.
  Future<LocationPermission> requestPermission() async {
    var status = await _provider.checkPermission();
    if (status == LocationPermission.denied) {
      status = await _provider.requestPermission();
    }
    return status;
  }

  /// Opens the system settings page for this app — the only way to recover
  /// from `deniedForever` on Android.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Returns the current position as a [GeoPoint], or null when the user
  /// denies permission or location services are unavailable.
  Future<GeoPoint?> getCurrentLocation() async {
    final enabled = await _provider.isLocationServiceEnabled();
    if (!enabled) return null;

    final permission = await _provider.checkPermission();
    // Never open the system dialog implicitly from a browse/post/chat load.
    // The caller must first use PermissionExplainerScreen's explicit action.
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;

    final position = await _provider.getCurrentPosition();
    return GeoPoint(position.latitude, position.longitude);
  }
}
