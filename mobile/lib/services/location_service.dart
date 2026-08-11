import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/services/location_provider.dart';

/// Fetches the user's real GPS position on explicit request only.
/// There is NO background tracking anywhere in this class.
class LocationService {
  final LocationProvider _provider;

  LocationService({LocationProvider? provider})
      : _provider = provider ?? const DeviceLocationProvider();

  /// Returns the current position as a [GeoPoint], or null when the user
  /// denies permission or location services are unavailable.
  Future<GeoPoint?> getCurrentLocation() async {
    final enabled = await _provider.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await _provider.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _provider.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await _provider.getCurrentPosition();
    return GeoPoint(position.latitude, position.longitude);
  }
}
