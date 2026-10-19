import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/job_preferences.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_preference_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/worker/job_alert_preferences_screen.dart';
class MockProfiles extends Mock implements ProfileService {}
JobModel sample(JobCategory category, double budget) => JobModel(id: '$category', userId: 'u', title: '', description: '', category: category, address: '', location: const GeoPoint(33, 72), budgetMin: 0, budgetMax: budget,
  preferredDate: DateTime(2026), createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  test('preferences validate empty categories, finite budgets and radius bounds', () {
    expect(const JobPreferences().valid, isFalse); expect(const JobPreferences(categories: [JobCategory.plumbing], minBudget: 100).valid, isTrue);
    expect(const JobPreferences(categories: [JobCategory.plumbing], maxDistanceKm: 0).valid, isFalse); expect(JobPreferences(categories: [JobCategory.plumbing], minBudget: double.nan).valid, isFalse);
  });
  test('board filtering uses category/budget/pin and never invents zero distance', () {
    final service = JobPreferenceService(); final jobs = [sample(JobCategory.plumbing, 2000), sample(JobCategory.cleaning, 2000), sample(JobCategory.plumbing, 500)];
    const prefs = JobPreferences(categories: [JobCategory.plumbing], minBudget: 1000, maxDistanceKm: 5);
    expect(service.applyLocal(jobs, prefs, null), isEmpty); expect(service.applyLocal(jobs, prefs, const GeoPoint(33, 72)), hasLength(1));
  });
  test('a client verification flag is read but never persisted by public user DTO saves', () {
    final user = UserModel.fromMap({'verifiedClient': true, 'role': 'user'}, 'u'); expect(user.verifiedClient, isTrue); expect(user.toMap().containsKey('verifiedClient'), isFalse);
  });
  testWidgets('load failure retries to a real missing-profile state', (tester) async {
    final profiles = MockProfiles(); when(() => profiles.getWorkerProfile('w')).thenThrow(StateError('offline'));
    await tester.pumpWidget(MaterialApp(home: JobAlertPreferencesScreen(workerId: 'w', profileService: profiles))); await tester.pumpAndSettle();
    when(() => profiles.getWorkerProfile('w')).thenAnswer((_) async => null); await tester.tap(find.text('Retry')); await tester.pumpAndSettle(); expect(find.text('Worker profile needed'), findsOneWidget);
  });
  testWidgets('distance filter without a service pin has an actionable validation error', (tester) async {
    final profiles = MockProfiles(); when(() => profiles.getWorkerProfile('w')).thenAnswer((_) async => WorkerProfile(uid: 'w', fullName: '', email: '', createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    await tester.pumpWidget(MaterialApp(home: JobAlertPreferencesScreen(workerId: 'w', profileService: profiles))); await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('job-pref-distance'))); await tester.tap(find.byKey(const Key('job-pref-distance'))); await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('job-pref-save'))); await tester.tap(find.byKey(const Key('job-pref-save'))); await tester.pump(); expect(find.textContaining('a service pin'), findsOneWidget);
    expect(find.byKey(const Key('job-pref-set-area')), findsOneWidget);
  });
}
