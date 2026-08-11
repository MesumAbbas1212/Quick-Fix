import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/services/location_provider.dart';
import 'package:quickfix/services/location_service.dart';

class _FakeLocationProvider implements LocationProvider {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position? position;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition() async => position ??
      Position(
        latitude: 31.5204,
        longitude: 74.3587,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

void main() {
  test('returns null when location services are disabled', () async {
    final fake = _FakeLocationProvider()..serviceEnabled = false;
    final service = LocationService(provider: fake);
    expect(await service.getCurrentLocation(), isNull);
  });

  test('requests permission when denied and returns null when refused', () async {
    final fake = _FakeLocationProvider()..permission = LocationPermission.denied;
    final service = LocationService(provider: fake);
    expect(await service.getCurrentLocation(), isNull);
  });

  test('returns GeoPoint when permission granted', () async {
    final fake = _FakeLocationProvider();
    final service = LocationService(provider: fake);
    final point = await service.getCurrentLocation();
    expect(point, isNotNull);
    expect(point!.latitude, closeTo(31.5204, 0.0001));
    expect(point.longitude, closeTo(74.3587, 0.0001));
  });
}
