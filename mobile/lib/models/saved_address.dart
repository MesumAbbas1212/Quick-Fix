import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/location_selection.dart';

class SavedAddress {
  final String id;
  final String label;
  final String address;
  final GeoPoint location;
  const SavedAddress({this.id = '', required this.label, required this.address, required this.location});
  LocationSelection get selection => LocationSelection(address: address, location: location);
  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'address': address, 'location': location};
  static List<SavedAddress> decode(Object? value) {
    if (value == null) return [];
    if (value is! List) throw const FormatException('Address book is not a list.');
    return value.asMap().entries.map((entry) {
      final raw = entry.value;
      if (raw is! Map || raw['address'] is! String || raw['location'] is! GeoPoint || !LocationSelection.valid(raw['location'] as GeoPoint)) {
        throw const FormatException('A saved address needs repair.');
      }
      return SavedAddress(id: raw['id'] is String && (raw['id'] as String).isNotEmpty ? raw['id'] as String : 'legacy-${entry.key}',
        label: raw['label'] is String ? raw['label'] as String : 'Saved address', address: raw['address'] as String, location: raw['location'] as GeoPoint);
    }).toList();
  }
}
