import 'package:cloud_firestore/cloud_firestore.dart';

class LocationSelection {
  final String address;
  final GeoPoint location;
  const LocationSelection({required this.address, required this.location});
  static GeoPoint? parse(String latitude, String longitude) {
    final lat = double.tryParse(latitude.trim()); final lng = double.tryParse(longitude.trim());
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite || lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return GeoPoint(double.parse(lat.toStringAsFixed(5)), double.parse(lng.toStringAsFixed(5)));
  }
  static bool valid(GeoPoint? point) => point != null && point.latitude.isFinite && point.longitude.isFinite &&
    point.latitude >= -90 && point.latitude <= 90 && point.longitude >= -180 && point.longitude <= 180;
}
