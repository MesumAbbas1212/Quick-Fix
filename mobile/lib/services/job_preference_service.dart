import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/job_preferences.dart';
import 'package:quickfix/services/auth_service.dart';
class JobPreferenceService {
  final AuthService? _injectedAuth;
  JobPreferenceService({AuthService? authService}) : _injectedAuth = authService;
  late final AuthService _auth = _injectedAuth ?? AuthService();
  List<JobModel> applyLocal(Iterable<JobModel> jobs, JobPreferences prefs, GeoPoint? origin) => jobs.where((job) {
    if (job.status != JobStatus.open || job.anonymized) return false;
    if (prefs.categories.isNotEmpty && !prefs.categories.contains(job.category)) return false;
    if (!job.budgetMax.isFinite || job.budgetMax < prefs.minBudget) return false;
    if (prefs.maxDistanceKm != null) {
      if (origin == null) return false;
      final km = Geolocator.distanceBetween(origin.latitude, origin.longitude, job.location.latitude, job.location.longitude) / 1000;
      if (km > prefs.maxDistanceKm!) return false;
    }
    return true;
  }).toList();
  Future<List<JobModel>> filterVerified(List<JobModel> jobs) async {
    final ids = jobs.map((job) => job.userId).toSet().toList(); final verified = <String>{}; var next = 0; var stopped = false;
    Future<void> read() async {
      while (!stopped && next < ids.length) {
        final uid = ids[next++]; final profile = await _auth.getUserProfile(uid).timeout(const Duration(seconds: 8));
        if (profile?.verifiedClient == true) verified.add(uid);
      }
    }
    try { await Future.wait(List.generate(math.min(8, ids.length), (_) => read())).timeout(const Duration(seconds: 20)); }
    finally { stopped = true; }
    return jobs.where((job) => verified.contains(job.userId)).toList();
  }
}
