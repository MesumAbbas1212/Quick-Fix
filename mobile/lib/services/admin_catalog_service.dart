import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/service_category.dart';
import 'package:quickfix/services/category_service.dart';

class AdminCatalogService {
  final FirebaseFirestore _firestore;
  AdminCatalogService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ServiceCategory>> watchCategories() => _firestore.collection('categories').snapshots().map((snapshot) {
    final result = <ServiceCategory>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = CategoryService.categoryFor(data, doc.id);
      if (category == null) continue;
      result.add(ServiceCategory(id: doc.id, category: category, name: (data['name'] ?? category.name).toString(),
        description: (data['description'] ?? '').toString(), iconPath: (data['icon'] ?? data['iconPath'] ?? '').toString(),
        isActive: data['isActive'] != false, sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0));
    }
    result.sort((a, b) => a.category.index.compareTo(b.category.index));
    return List.unmodifiable(result);
  });

  Stream<List<AppLanguage>> watchLanguages() => _firestore.collection('languages').orderBy('englishName').snapshots().map((snapshot) => List.unmodifiable(snapshot.docs.map((doc) {
    final data = doc.data();
    return AppLanguage(code: doc.id, nativeName: (data['nativeName'] ?? '').toString(), englishName: (data['englishName'] ?? '').toString(), isActive: data['isActive'] != false);
  })));

  String _categoryName(String name) {
    final value = name.trim();
    if (!JobCategory.values.any((item) => item.name == value)) {
      throw ArgumentError('Category must exactly match a JobCategory value: ${JobCategory.values.map((item) => item.name).join(', ')}.');
    }
    return value;
  }

  Future<void> saveCategory({required String name, required String icon, required bool isActive}) async {
    final id = _categoryName(name);
    final ref = _firestore.collection('categories').doc(id);
    final existing = await ref.get();
    final data = <String, dynamic>{'name': id, 'icon': icon.trim(), 'isActive': isActive, 'updatedAt': FieldValue.serverTimestamp()};
    if (existing.exists) { await ref.update(data); } else { await ref.set({...data, 'createdAt': FieldValue.serverTimestamp()}); }
  }

  Future<void> renameCategory({required String from, required String to}) async {
    final oldId = _categoryName(from); final newId = _categoryName(to);
    if (oldId == newId) return;
    final oldRef = _firestore.collection('categories').doc(oldId);
    final old = await oldRef.get();
    if (!old.exists) throw StateError('Category $oldId no longer exists.');
    final data = old.data()!;
    final batch = _firestore.batch();
    batch.set(_firestore.collection('categories').doc(newId), {...data, 'name': newId, 'updatedAt': FieldValue.serverTimestamp()});
    batch.delete(oldRef);
    await batch.commit();
  }

  Future<void> setCategoryActive(String name, bool active) async {
    final id = _categoryName(name);
    await _firestore.collection('categories').doc(id).update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<int> jobCountForCategory(String name) async {
    final id = _categoryName(name);
    final result = await _firestore.collection('jobs').where('category', isEqualTo: id).count().get();
    return result.count ?? 0;
  }

  static final RegExp _languagePattern = RegExp(r'^[a-z]{2,3}(-[A-Z]{2})?$');
  Future<void> saveLanguage({required String code, required String nativeName, required String englishName}) async {
    final id = code.trim();
    if (!_languagePattern.hasMatch(id)) throw ArgumentError('Language code must match BCP-47 format such as en or pt-BR.');
    if (nativeName.trim().isEmpty || englishName.trim().isEmpty) throw ArgumentError('Enter both native and English language names.');
    final ref = _firestore.collection('languages').doc(id);
    final current = await ref.get();
    if (current.exists) throw StateError('A language with code $id already exists.');
    await ref.set({'code': id, 'nativeName': nativeName.trim(), 'englishName': englishName.trim(), 'isActive': true, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> setLanguageActive(String code, bool active) async {
    if (!_languagePattern.hasMatch(code)) throw ArgumentError('Invalid BCP-47 language code.');
    await _firestore.collection('languages').doc(code).update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});
  }
}
