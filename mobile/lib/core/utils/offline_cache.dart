import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/shared/models/job_model.dart';
import 'package:quickfix/shared/models/service_category.dart';

/// Caches the job feed and category list locally with shared_preferences so
/// screens render instantly offline and fall back to cached data.
class OfflineCache {
  static const _jobsKey = 'cached_jobs';
  static const _categoriesKey = 'cached_categories';

  Future<void> cacheJobs(List<JobModel> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _jobsKey,
      jsonEncode(jobs.map(_jobToMap).toList()),
    );
  }

  Future<List<JobModel>> readCachedJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jobsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _jobFromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cacheCategories(List<ServiceCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(
        categories
            .map((c) => {
                  'id': c.id,
                  'category': c.category.name,
                  'name': c.name,
                  'description': c.description,
                  'iconPath': c.iconPath,
                })
            .toList(),
      ),
    );
  }

  Future<List<ServiceCategory>> readCachedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) {
          final m = e as Map<String, dynamic>;
          return ServiceCategory(
            id: m['id'] ?? '',
            category: JobCategory.values.firstWhere(
              (c) => c.name == m['category'],
              orElse: () => JobCategory.other,
            ),
            name: m['name'] ?? '',
            description: m['description'] ?? '',
            iconPath: m['iconPath'] ?? '',
          );
        })
        .toList();
  }

  Map<String, dynamic> _jobToMap(JobModel j) {
    final map = j.toMap();
    map['id'] = j.id;
    map['location'] = {
      'lat': j.location.latitude,
      'lng': j.location.longitude,
    };
    map['preferredDate'] = j.preferredDate.toIso8601String();
    if (j.preferredTime != null) {
      map['preferredTime'] = j.preferredTime!.toIso8601String();
    }
    map['createdAt'] = j.createdAt.toIso8601String();
    map['updatedAt'] = j.updatedAt.toIso8601String();
    if (j.assignedAt != null) {
      map['assignedAt'] = j.assignedAt!.toIso8601String();
    }
    if (j.completedAt != null) {
      map['completedAt'] = j.completedAt!.toIso8601String();
    }
    return map;
  }

  JobModel _jobFromMap(Map<String, dynamic> m) {
    final location = m['location'];
    return JobModel(
      id: m['id'] ?? 'cache',
      userId: m['userId'] ?? '',
      workerId: m['workerId'],
      title: m['title'] ?? '',
      description: m['description'] ?? '',
      category: JobCategory.values.firstWhere(
        (e) => e.name == m['category'],
        orElse: () => JobCategory.other,
      ),
      address: m['address'] ?? '',
      location: location is Map<String, dynamic>
          ? GeoPoint(
              (location['lat'] as num).toDouble(),
              (location['lng'] as num).toDouble(),
            )
          : const GeoPoint(0, 0),
      budgetMin: (m['budgetMin'] ?? 0).toDouble(),
      budgetMax: (m['budgetMax'] ?? 0).toDouble(),
      preferredDate: DateTime.tryParse(m['preferredDate'] ?? '') ?? DateTime.now(),
      preferredTime: m['preferredTime'] != null
          ? DateTime.tryParse(m['preferredTime'] as String)
          : null,
      status: JobStatus.values.firstWhere(
        (e) => e.name == m['status'],
        orElse: () => JobStatus.open,
      ),
      rating: (m['rating'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(m['updatedAt'] ?? '') ?? DateTime.now(),
      assignedAt: DateTime.tryParse(m['assignedAt'] ?? ''),
      completedAt: DateTime.tryParse(m['completedAt'] ?? ''),
    );
  }
}
