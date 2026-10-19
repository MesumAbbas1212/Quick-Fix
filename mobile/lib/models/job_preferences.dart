import 'package:quickfix/models/job_model.dart';
class JobPreferences {
  final List<JobCategory> categories;
  final double? maxDistanceKm;
  final double minBudget;
  final bool onlyVerifiedClients;
  const JobPreferences({this.categories = const [], this.maxDistanceKm, this.minBudget = 0, this.onlyVerifiedClients = false});
  factory JobPreferences.fromMap(Object? value) {
    final data = value is Map ? value : const {};
    return JobPreferences(categories: (data['categories'] is List ? data['categories'] as List : const []).whereType<String>()
      .where((name) => JobCategory.values.any((category) => category.name == name)).map((name) => JobCategory.values.firstWhere((category) => category.name == name)).toSet().toList(),
      maxDistanceKm: (data['maxDistanceKm'] as num?)?.toDouble(), minBudget: (data['minBudget'] as num?)?.toDouble() ?? 0, onlyVerifiedClients: data['onlyVerifiedClients'] == true);
  }
  bool get valid => categories.isNotEmpty && minBudget.isFinite && minBudget >= 0 && (maxDistanceKm == null || (maxDistanceKm!.isFinite && maxDistanceKm! >= 1 && maxDistanceKm! <= 100));
  Map<String, dynamic> toMap() => {'categories': categories.map((category) => category.name).toList(), 'maxDistanceKm': maxDistanceKm, 'minBudget': minBudget, 'onlyVerifiedClients': onlyVerifiedClients};
}
