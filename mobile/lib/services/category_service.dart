import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/service_category.dart';

/// Reads both admin catalog (`name` is an enum identifier) and legacy seeded
/// catalog (`category` plus a display name). Does not modify existing documents.
class CategoryService {
  final FirebaseFirestore _firestore;
  CategoryService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  static String _normalize(String value) => value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  static JobCategory? categoryFor(Map<String, dynamic> data, String id) {
    for (final raw in [data['category'], data['name'], id]) {
      if (raw is! String) continue;
      for (final category in JobCategory.values) {
        if (_normalize(raw) == _normalize(category.name)) return category;
      }
    }
    return null; // Never turn an unknown admin label into "Other".
  }

  static List<ServiceCategory> get standardCategories => List.unmodifiable([
    for (final category in JobCategory.values) ServiceCategory(id: category.name,
      category: category, name: category.name, description: '', iconPath: ''),
  ]);

  Future<List<ServiceCategory>> getCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    if (snapshot.docs.isEmpty) return standardCategories;
    final categories = <JobCategory, ServiceCategory>{};
    for (final document in snapshot.docs) {
      final data = document.data(); final category = categoryFor(data, document.id);
      if (category == null) continue;
      final item = ServiceCategory(id: document.id, category: category,
        name: (data['name'] ?? category.name).toString(),
        description: (data['description'] ?? '').toString(),
        iconPath: (data['iconPath'] ?? data['icon'] ?? '').toString(),
        isActive: data['isActive'] != false, sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0);
      // Avoid duplicates if a legacy seed and an admin document coexist.
      if (!categories.containsKey(category) || document.id == category.name) categories[category] = item;
    }
    final result = categories.values.toList()..sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order == 0 ? a.category.index.compareTo(b.category.index) : order;
    });
    return List.unmodifiable(result);
  }
}
