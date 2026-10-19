import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/utils/location_access.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/models/location_selection.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';

class LocationPickerScreen extends StatefulWidget {
  final GeoPoint? initialLocation;
  final String initialAddress;
  final LocationService? locationService;
  final UrlLauncher? urlLauncher;
  const LocationPickerScreen({super.key, this.initialLocation, this.initialAddress = '', this.locationService, this.urlLauncher});
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}
class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final LocationService _locations = widget.locationService ?? LocationService();
  late final UrlLauncher _maps = widget.urlLauncher ?? const MapLauncher();
  late final TextEditingController _address = TextEditingController(text: widget.initialAddress);
  late final TextEditingController _lat = TextEditingController(text: widget.initialLocation?.latitude.toStringAsFixed(5) ?? '');
  late final TextEditingController _lng = TextEditingController(text: widget.initialLocation?.longitude.toStringAsFixed(5) ?? '');
  final _form = GlobalKey<FormState>();
  bool _manual = false;
  bool _busy = false;
  String? _error;
  GeoPoint? get _point => LocationSelection.parse(_lat.text, _lng.text);
  @override
  void dispose() { _address.dispose(); _lat.dispose(); _lng.dispose(); super.dispose(); }
  Future<void> _locate() async {
    if (_busy) return;
    if (!await explainLocationAccess(context, locationService: _locations, purpose: 'Select one location pin for your job or saved address')) {
      if (mounted) setState(() { _manual = true; _error = 'Location access was not granted. Enter coordinates manually instead.'; });
      return;
    }
    if (!mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final point = await _locations.getCurrentLocation().timeout(const Duration(seconds: 8));
      if (point == null || !LocationSelection.valid(point)) throw StateError('No valid fix');
      if (mounted) setState(() { _lat.text = point.latitude.toStringAsFixed(5); _lng.text = point.longitude.toStringAsFixed(5); });
    } catch (_) { if (mounted) setState(() { _manual = true; _error = 'Could not get a position. Retry or enter coordinates manually.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  Future<void> _openMaps() async {
    final point = _point; if (point == null || _busy) return;
    try {
      final opened = await _maps.openLocation(point.latitude, point.longitude).timeout(const Duration(seconds: 8));
      if (!opened) throw StateError('No map app');
    } catch (_) { if (mounted) setState(() { _error = 'Could not open Maps. Check the coordinates and try again.'; }); }
  }
  void _select() {
    final point = _point;
    if (!_form.currentState!.validate() || point == null || _busy) return;
    Navigator.of(context).pop(LocationSelection(address: _address.text.trim(), location: point));
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Choose location', maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: SafeArea(child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Selected coordinates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
        Text(_point == null ? 'No pin selected yet' : '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}', key: const Key('location-coordinate-card'), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8), const Text('One-shot only. No tracking, embedded map or automatic address lookup. Add a readable address or landmark yourself.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        if (_point == null) TextButton(key: const Key('location-manual-fallback'), onPressed: _busy ? null : () => setState(() { _manual = true; }), child: const Text('Enter manually')),
        if (_point != null) TextButton.icon(key: const Key('location-open-maps'), onPressed: _busy ? null : _openMaps, icon: const Icon(Icons.map_outlined), label: const Text('Verify in Maps')),
      ])), const SizedBox(height: 16),
      OutlinedButton.icon(key: const Key('location-current'), onPressed: _busy ? null : _locate, icon: const Icon(Icons.my_location), label: Text(_busy ? 'Finding position…' : 'Use my current location')),
      SwitchListTile(key: const Key('location-advanced'), contentPadding: EdgeInsets.zero, title: const Text('Manual coordinates (advanced)', style: TextStyle(fontSize: 14)),
        value: _manual, onChanged: _busy ? null : (value) => setState(() { _manual = value; })),
      if (_manual) ...[
        TextFormField(key: const Key('location-latitude'), controller: _lat, enabled: !_busy, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Latitude (−90 to 90)'), validator: (_) => _point == null ? 'Enter finite latitude/longitude within range.' : null),
        const SizedBox(height: 12), TextFormField(key: const Key('location-longitude'), controller: _lng, enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Longitude (−180 to 180)')),
      ],
      const SizedBox(height: 16), TextFormField(key: const Key('location-address'), controller: _address, enabled: !_busy, maxLength: 500, minLines: 1, maxLines: 3,
        textDirection: contentDirection(_address.text), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Address / landmark'),
        validator: (value) => value == null || value.trim().isEmpty ? 'Add an address or landmark.' : null),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
      ElevatedButton(key: const Key('location-use'), onPressed: _busy || _point == null || _address.text.trim().isEmpty ? null : _select, child: const Text('Use this location')),
    ]))),
  );
}
