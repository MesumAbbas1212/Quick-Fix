import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/location_selection.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/working_day.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/client/location_picker_screen.dart';

class AvailabilitySettingsScreen extends StatefulWidget {
  final String workerId;
  final ProfileService? profileService;
  final LocationService? locationService;
  const AvailabilitySettingsScreen({super.key, required this.workerId, this.profileService, this.locationService});
  @override
  State<AvailabilitySettingsScreen> createState() => _AvailabilitySettingsScreenState();
}
class _AvailabilitySettingsScreenState extends State<AvailabilitySettingsScreen> {
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late Future<WorkerProfile?> _future = _load();
  bool _available = true, _dirty = false, _busy = false, _allowPop = false;
  int _radius = 5;
  GeoPoint? _point;
  Map<String, WorkingDay> _hours = WorkingDay.decode(null);
  List<String> _daysOff = [];
  String? _error;
  Future<WorkerProfile?> _load() async {
    final profile = await _profiles.getWorkerProfile(widget.workerId).timeout(const Duration(seconds: 10));
    if (profile != null) { _available = profile.isAvailable; _radius = profile.serviceRadiusKm.clamp(1, 50).toInt(); _point = profile.location;
      _hours = {for (final key in WorkingDay.keys) key: profile.workingHours[key] ?? const WorkingDay()}; _daysOff = [...profile.daysOff]; }
    return profile;
  }
  void _change(VoidCallback action) => setState(() { action(); _dirty = true; });
  void _pop() { setState(() { _allowPop = true; }); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.of(context).pop(true); }); }
  Future<void> _back() async {
    if (_busy || _allowPop) return;
    final leave = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Discard unsaved availability?'),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
        TextButton(key: const Key('availability-discard'), onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Discard'))]));
    if (leave == true && mounted) _pop();
  }
  Future<void> _chooseHours(String key, bool start) async {
    final day = _hours[key]!; final value = start ? day.fromMinutes : day.toMinutes;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (value ~/ 60).clamp(0, 23).toInt(), minute: (value % 60).clamp(0, 59).toInt()));
    if (time != null && mounted) _change(() { _hours[key] = start ? day.copyWith(fromMinutes: time.hour * 60 + time.minute) : day.copyWith(toMinutes: time.hour * 60 + time.minute); });
  }
  Future<void> _pin() async {
    final selection = await Navigator.of(context).push<LocationSelection>(MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: _point,
      initialAddress: 'General service area', locationService: widget.locationService)));
    if (selection != null && mounted) _change(() { _point = selection.location; });
  }
  Future<void> _addDayOff() async {
    final now = DateTime.now(); final first = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(context: context, initialDate: first, firstDate: first, lastDate: first.add(const Duration(days: 365)));
    if (date != null && mounted) _change(() { _daysOff = {..._daysOff, intl.DateFormat('yyyy-MM-dd', 'en').format(date)}.toList()..sort(); });
  }
  Future<void> _save() async {
    if (_busy) return;
    if (_hours.values.any((day) => !day.valid)) { setState(() { _error = 'Each working day must end after it starts; overnight shifts are not supported.'; }); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await _profiles.saveAvailability(uid: widget.workerId, isAvailable: _available, radiusKm: _radius, hours: _hours, daysOff: _daysOff, location: _point);
      if (mounted) { _dirty = false; _pop(); }
    } catch (_) { if (mounted) setState(() { _error = 'Could not save availability. Your draft remains here; retry.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  String _clock(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => PopScope<Object?>(canPop: _allowPop || (!_dirty && !_busy), onPopInvokedWithResult: (didPop, result) { if (!didPop) _back(); },
    child: Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Availability & area', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(child: FutureBuilder<WorkerProfile?>(future: _future, builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorState(message: 'Could not load availability.', onRetry: () => setState(() { _future = _load(); }));
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingList();
        if (snapshot.data == null) return EmptyState(icon: Icons.person_outline, title: 'Worker profile needed', message: 'Complete your worker profile before setting a service area.', action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to profile')));
        return ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(child: Column(children: [SwitchListTile(key: const Key('availability-master'), contentPadding: EdgeInsets.zero, title: const Text('Available for new work'), value: _available, onChanged: _busy ? null : (value) => _change(() { _available = value; })),
            const Text('This switch keeps its existing meaning. Hours and days off are informational; they do not automatically change availability or track you.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted))])),
          const SizedBox(height: 14), AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Service radius: $_radius km', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Slider(key: const Key('availability-radius'), value: _radius.toDouble(), min: 1, max: 50, divisions: 49, onChanged: _busy ? null : (value) => _change(() { _radius = value.round(); })),
            Text(_point == null ? 'No service pin saved. Distance-based job preferences need one.' : 'Around ${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            TextButton(key: const Key('availability-pin'), onPressed: _busy ? null : _pin, child: const Text('Choose service-area pin')),
            const Text('Use a general service-area landmark: the worker profile/pin is visible to signed-in users. Clock hours use the local values you enter.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ])), const SizedBox(height: 16),
          for (final key in WorkingDay.keys) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(child: Column(children: [
            SwitchListTile(key: Key('working-day-$key'), contentPadding: EdgeInsets.zero, title: Text(key.toUpperCase()), value: _hours[key]!.enabled, onChanged: _busy ? null : (value) => _change(() { _hours[key] = _hours[key]!.copyWith(enabled: value); })),
            if (_hours[key]!.enabled) Wrap(spacing: 10, children: [OutlinedButton(onPressed: _busy ? null : () => _chooseHours(key, true), child: Text('From ${_clock(_hours[key]!.fromMinutes)}')),
              OutlinedButton(onPressed: _busy ? null : () => _chooseHours(key, false), child: Text('To ${_clock(_hours[key]!.toMinutes)}'))]),
          ]))),
          const Text('Days off', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Wrap(spacing: 8, children: [for (final day in _daysOff) InputChip(label: Text(day), onDeleted: _busy ? null : () => _change(() { _daysOff.remove(day); }))]),
          TextButton(key: const Key('availability-day-off'), onPressed: _busy ? null : _addDayOff, child: const Text('Add day off')),
          if (_error != null) Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed)),
          ElevatedButton(key: const Key('availability-save'), onPressed: !_dirty || _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save availability')),
        ]);
      })),
    ));
}
