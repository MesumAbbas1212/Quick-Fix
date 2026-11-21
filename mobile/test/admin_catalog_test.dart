import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/service_category.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_catalog_service.dart';
import 'package:quickfix/views/admin/admin_catalog_screen.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class _Catalog extends Mock implements AdminCatalogService {}
final _user = UserModel(uid: 'admin', email: 'a@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
ServiceCategory _category() => const ServiceCategory(id: 'plumbing', category: JobCategory.plumbing, name: 'plumbing', description: '', iconPath: 'wrench');
void _streams(_Catalog service, {Stream<List<ServiceCategory>>? categories, Stream<List<AppLanguage>>? languages}) {
  when(() => service.watchCategories()).thenAnswer((_) => categories ?? Stream.value(const <ServiceCategory>[]));
  when(() => service.watchLanguages()).thenAnswer((_) => languages ?? Stream.value(const <AppLanguage>[]));
}
void main() {
  testWidgets('catalog loading state', (tester) async {
    final service = _Catalog(); final controller = StreamController<List<ServiceCategory>>(); addTearDown(controller.close); _streams(service, categories: controller.stream);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminCatalogScreen(user: _user, catalogService: service)))); expect(find.byType(AdminLoading), findsOneWidget);
  });
  testWidgets('catalog errors expose retry', (tester) async {
    final service = _Catalog(); _streams(service, categories: Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminCatalogScreen(user: _user, catalogService: service)))); await tester.pumpAndSettle(); expect(find.text('Something went wrong'), findsOneWidget);
  });
  testWidgets('catalog empty state is explicit', (tester) async {
    final service = _Catalog(); _streams(service);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminCatalogScreen(user: _user, catalogService: service)))); await tester.pumpAndSettle(); expect(find.text('No categories'), findsOneWidget);
  });
  testWidgets('populated categories and exact enum category write', (tester) async {
    final service = _Catalog(); _streams(service, categories: Stream.value([_category()]));
    when(() => service.saveCategory(name: 'plumbing', icon: 'wrench', isActive: true)).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminCatalogScreen(user: _user, catalogService: service)))); await tester.pumpAndSettle(); expect(find.text('plumbing'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-catalog-add'))); await tester.pumpAndSettle(); await tester.enterText(find.byKey(const Key('admin-category-name')), 'plumbing');
    await tester.enterText(find.byType(TextField).last, 'wrench'); await tester.tap(find.byKey(const Key('admin-category-save'))); await tester.pumpAndSettle();
    verify(() => service.saveCategory(name: 'plumbing', icon: 'wrench', isActive: true)).called(1);
  });
  testWidgets('language add validates and calls exact save method', (tester) async {
    final service = _Catalog(); _streams(service); when(() => service.saveLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu')).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminCatalogScreen(user: _user, catalogService: service)))); await tester.pumpAndSettle();
    await tester.tap(find.text('Languages')); await tester.pumpAndSettle(); expect(find.text('No languages'), findsOneWidget); await tester.tap(find.byKey(const Key('admin-catalog-add'))); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-language-code')), 'ur'); await tester.enterText(find.byType(TextField).at(1), 'اردو'); await tester.enterText(find.byType(TextField).at(2), 'Urdu');
    await tester.tap(find.byKey(const Key('admin-language-save'))); await tester.pumpAndSettle(); verify(() => service.saveLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu')).called(1);
  });
}
