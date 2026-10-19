import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/job_preferences.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/worker/availability_settings_screen.dart';

class JobAlertPreferencesScreen extends StatefulWidget {
  final String workerId;
  final ProfileService? profileService;
  const JobAlertPreferencesScreen({super.key, required this.workerId, this.profileService});
  @override
  State<JobAlertPreferencesScreen> createState() => _JobAlertPreferencesScreenState();
}
class _JobAlertPreferencesScreenState extends State<JobAlertPreferencesScreen> {
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late Future<WorkerProfile?> _future = _load();
  final _budget = TextEditingController();
  Set<JobCategory> _categories = {};
  bool _distance = false, _verified = false, _busy = false;
  double _km = 10;
  GeoPoint? _origin;
  String? _error;
  Future<WorkerProfile?> _load() async {
    final worker = await _profiles.getWorkerProfile(widget.workerId).timeout(const Duration(seconds: 10));
    final prefs = worker?.jobPrefs ?? const JobPreferences();
    _categories = prefs.categories.isEmpty ? JobCategory.values.toSet() : prefs.categories.toSet(); _origin = worker?.location;
    _distance = prefs.maxDistanceKm != null && prefs.maxDistanceKm!.isFinite; _km = _distance ? prefs.maxDistanceKm!.clamp(1, 100).toDouble() : 10;
    _verified = prefs.onlyVerifiedClients; _budget.text = prefs.minBudget.isFinite ? prefs.minBudget.toString() : '0';
    return worker;
  }
  @override
  void dispose() { _budget.dispose(); super.dispose(); }
  Future<void> _setArea() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AvailabilitySettingsScreen(workerId: widget.workerId, profileService: widget.profileService)));
    try { final worker = await _profiles.getWorkerProfile(widget.workerId).timeout(const Duration(seconds: 8)); if (mounted) setState(() { _origin = worker?.location; }); }
    catch (_) { if (mounted) setState(() { _error = 'Could not refresh the service pin. Retry after setting your area.'; }); }
  }
  Future<void> _save() async {
    if (_busy) return;
    final minimum = double.tryParse(_budget.text.trim());
    final prefs = JobPreferences(categories: _categories.toList(), maxDistanceKm: _distance ? _km : null, minBudget: minimum ?? double.nan, onlyVerifiedClients: _verified);
    if (!prefs.valid || (_distance && _origin == null)) { setState(() { _error = 'Select at least one category, a nonnegative budget and a service pin for distance filtering.'; }); return; }
    setState(() { _busy = true; _error = null; });
    try { await _profiles.saveJobPreferences(widget.workerId, prefs); if (mounted) Navigator.of(context).pop(true); }
    catch (_) { if (mounted) setState(() { _error = 'Could not save job preferences. Your draft remains; retry.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Job alert preferences', maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: SafeArea(child: FutureBuilder<WorkerProfile?>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'Could not load job preferences.', onRetry: () => setState(() { _future = _load(); }));
      if (snapshot.connectionState == ConnectionState.waiting) return const LoadingList();
      if (snapshot.data == null) return EmptyState(icon: Icons.person_outline, title: 'Worker profile needed', message: 'Set up your worker profile first.', action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to profile')));
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('These settings filter the loaded Jobs board. They are not push alerts or a second matching system.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)), const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final category in JobCategory.values) FilterChip(key: Key('job-pref-${category.name}'), label: Text(jobCategoryLabel(category)), selected: _categories.contains(category),
          onSelected: _busy ? null : (selected) => setState(() { selected ? _categories.add(category) : _categories.remove(category); }))]),
        const SizedBox(height: 16), SwitchListTile(key: const Key('job-pref-distance'), title: const Text('Limit distance from my service pin'), contentPadding: EdgeInsets.zero,
          value: _distance, onChanged: _busy ? null : (value) => setState(() { _distance = value; })),
        if (_distance) ...[Text('Maximum: ${_km.toStringAsFixed(1)} km'), Slider(value: _km, min: 1, max: 100, divisions: 99, onChanged: _busy ? null : (value) => setState(() { _km = value; })),
          if (_origin == null) TextButton(key: const Key('job-pref-set-area'), onPressed: _busy ? null : _setArea, child: const Text('Set service-area pin first'))],
        TextField(key: const Key('job-pref-budget'), controller: _budget, enabled: !_busy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum posted maximum budget (PKR)')),
        const SizedBox(height: 12), SwitchListTile(key: const Key('job-pref-verified'), contentPadding: EdgeInsets.zero, title: const Text('Only admin-flagged clients'),
          subtitle: const Text('Uses an optional admin-maintained client flag, not automated identity/background checks. With no flagged clients the board is empty.'), value: _verified, onChanged: _busy ? null : (value) => setState(() { _verified = value; })),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
        ElevatedButton(key: const Key('job-pref-save'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save job preferences')),
      ]);
    })),
  ));
}
