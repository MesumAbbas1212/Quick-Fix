import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/job_image_thumb.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/views/client/category_grid_screen.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

class MockJobService extends Mock implements JobService {}

class MockImageStore extends Mock implements LocalImageStore {}
class MockProfileService extends Mock implements ProfileService {}
class MockLocationService extends Mock implements LocationService {}

/// 1x1 transparent PNG, valid image data for widget preview tests.
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05,
  0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
]);

UserModel _user() {
  return UserModel(
    uid: 'u1',
    email: 'client@quickfix.com',
    fullName: 'Ahmed Ali',
    phone: '03001234567',
    role: UserRole.user,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

JobModel _job({
  String id = 'j1',
  JobStatus status = JobStatus.open,
  List<String> images = const [],
}) {
  return JobModel(
    id: id,
    userId: 'u1',
    title: 'AC Repair',
    description: 'Split AC not cooling',
    category: JobCategory.applianceRepair,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.5, 74.3),
    budgetMin: 2000,
    budgetMax: 3500,
    preferredDate: DateTime.now().add(const Duration(days: 1)),
    status: status,
    images: images,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockJobService jobService;

  setUp(() {
    jobService = MockJobService();
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value(<JobModel>[]));
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ClientHomeScreen(user: _user(), jobService: jobService),
    ));
    await tester.pump();
  }

  testWidgets('greets the client by first name', (tester) async {
    await pumpHome(tester);

    expect(find.textContaining('Ahmed'), findsWidgets);
    expect(find.text('Hi, Ahmed!'), findsOneWidget);
  });

  testWidgets('shows Post a Job hero and pushes PostJobScreen', (tester) async {
    await pumpHome(tester);

    expect(find.text('Post a Job'), findsWidgets);
    await tester.tap(find.byKey(const Key('post-job-cta')));
    await tester.pumpAndSettle();

    expect(find.byType(PostJobScreen), findsOneWidget);
  });

  testWidgets('lists my posted jobs from the service stream', (tester) async {
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value([_job()]));

    await pumpHome(tester);

    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.textContaining('PKR'), findsOneWidget);
  });

  testWidgets('shows status chip for in-progress job', (tester) async {
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value([_job(id: 'j2', status: JobStatus.inProgress)]));

    await pumpHome(tester);

    expect(find.text('In Progress'), findsOneWidget);
  });

  testWidgets('shows empty state when no jobs posted', (tester) async {
    await pumpHome(tester);

    expect(find.text('No jobs posted yet'), findsOneWidget);
  });

  testWidgets('posted job card shows the uploaded photo thumbnail',
      (tester) async {
    final imageStore = MockImageStore();
    when(() => imageStore.readImage('/data/job_images/pic.jpg'))
        .thenAnswer((_) async => _tinyPng);
    when(() => jobService.watchUserJobs('u1')).thenAnswer((_) =>
        Stream.value([
          _job(images: const ['/data/job_images/pic.jpg']),
        ]));

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ClientHomeScreen(
        user: _user(),
        jobService: jobService,
        imageStore: imageStore,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(JobImageThumb), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Browse by category opens the grid and preserves injectable services', (tester) async {
    final profiles = MockProfileService();
    final location = MockLocationService();
    when(() => profiles.searchWorkers(limit: 500))
        .thenAnswer((_) async => <WorkerProfile>[]);
    when(() => location.getCurrentLocation()).thenAnswer((_) async => null);
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ClientHomeScreen(
        user: _user(), jobService: jobService,
        profileService: profiles, locationService: location,
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('browse-category-entry')));
    await tester.pumpAndSettle();
    final grid = tester.widget<CategoryGridScreen>(find.byType(CategoryGridScreen));
    expect(grid.profileService, same(profiles));
    expect(grid.locationService, same(location));
    expect(grid.jobService, same(jobService));
    expect(find.text('Browse by category'), findsOneWidget);
    expect(find.text('No workers available yet'), findsOneWidget);
  });

}
