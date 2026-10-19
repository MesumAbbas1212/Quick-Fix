import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/utils/location_access.dart';
import 'package:quickfix/services/location_service.dart';
class MockLocation extends Mock implements LocationService {}
void main() {
  test('passive permission check accepts existing foreground grants without requesting one', () async {
    final location = MockLocation();
    when(() => location.getPermissionStatus()).thenAnswer((_) async => LocationPermission.whileInUse);
    expect(await hasLocationAccess(location), isTrue);
    when(() => location.getPermissionStatus()).thenAnswer((_) async => LocationPermission.always);
    expect(await hasLocationAccess(location), isTrue);
    when(() => location.getPermissionStatus()).thenAnswer((_) async => LocationPermission.denied);
    expect(await hasLocationAccess(location), isFalse);
    verifyNever(() => location.requestPermission());
  });
}
