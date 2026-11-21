import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_counts.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/service_category.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_catalog_service.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_shell.dart';
import 'package:quickfix/views/auth/app_shell.dart';

class _Auth extends Mock implements AuthService {}
class _Admin extends Mock implements AdminService {}
class _Catalog extends Mock implements AdminCatalogService {}
class _Release extends Mock implements AppReleaseService {}
void main() {
  testWidgets('AppShell derives administrator routing from the authenticated profile', (tester) async {
    final user = UserModel(uid: 'admin', email: 'admin@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
    final auth = _Auth(); final admin = _Admin(); final catalog = _Catalog(); final release = _Release();
    when(() => auth.watchUser('admin')).thenAnswer((_) => Stream.value(user));
    when(() => admin.counts()).thenAnswer((_) async => const AdminCounts());
    when(() => admin.watchReports(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminReportRow>[]));
    when(() => admin.watchUsers(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminAccountRow>[]));
    when(() => admin.watchWorkers(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminAccountRow>[]));
    when(() => admin.watchPendingVerifications(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminAccountRow>[]));
    when(() => catalog.watchCategories()).thenAnswer((_) => Stream.value(const <ServiceCategory>[]));
    when(() => catalog.watchLanguages()).thenAnswer((_) => Stream.value(const <AppLanguage>[]));
    when(() => release.checkForUpdate()).thenAnswer((_) async => const AppReleaseDecision(currentBuild: 1));
    await tester.pumpWidget(MaterialApp(home: AppShell(user: user, authService: auth, adminService: admin, adminCatalogService: catalog, releaseService: release)));
    await tester.pumpAndSettle();
    expect(find.byType(AdminShell), findsOneWidget); expect(find.byKey(const Key('admin-mode-chip')), findsOneWidget);
    expect(find.text('ClientShell'), findsNothing);
  });
}
