import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/views/jobs/navigate_to_job_screen.dart';
class MockJobs extends Mock implements JobService {}
class MockLocations extends Mock implements LocationService {}
class MockMaps extends Mock implements UrlLauncher {}
JobModel destination() => JobModel(id: 'j', userId: 'c', workerId: 'w', title: 'Work', description: '', category: JobCategory.plumbing, address: 'Attock', location: const GeoPoint(33, 72), status: JobStatus.assigned,
  budgetMin: 1, budgetMax: 2, preferredDate: DateTime(2026), createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  test('distance is unknown without an origin and uses real straight-line positions', () {
    expect(LocationService.distanceKm(null, const GeoPoint(33, 72)), isNull); expect(LocationService.distanceKm(const GeoPoint(33, 72), const GeoPoint(33, 72)), 0);
    expect(LocationService.distanceKm(const GeoPoint(33, 72), const GeoPoint(33.01, 72)), closeTo(1.11, .02));
  });
  test('a missing legacy coordinate is not confused with an explicitly selected 0,0', () {
    expect(JobModel.fromMap({}, 'j').hasDisclosedLocation, isFalse); expect(destination().copyWith(location: const GeoPoint(0, 0)).hasDisclosedLocation, isTrue);
  });
  testWidgets('Maps works without any permission request or automatic GPS fix', (tester) async {
    final jobs = MockJobs(); final locations = MockLocations(); final maps = MockMaps();
    when(() => jobs.watchJob('j')).thenAnswer((_) => Stream.value(destination())); when(() => maps.openLocation(33, 72)).thenAnswer((_) async => true);
    await tester.pumpWidget(MaterialApp(home: NavigateToJobScreen(jobId: 'j', workerId: 'w', jobService: jobs, locationService: locations, urlLauncher: maps))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigate-open-maps'))); await tester.pumpAndSettle(); verify(() => maps.openLocation(33, 72)).called(1); verifyNever(() => locations.getCurrentLocation()); verifyNever(() => locations.requestPermission());
  });
}
