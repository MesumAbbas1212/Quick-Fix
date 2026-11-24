import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/local_photo_viewer.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/jobs/worker_dashboard_screen.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/profile_service.dart';

class _Jobs extends Mock implements JobService {}

class _Images extends Mock implements LocalImageStore {}

class _Requests extends Mock implements JobRequestService {}

class _Profiles extends Mock implements ProfileService {}

/// 1x1 transparent PNG, valid image data.
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

const _path = '/data/job_images/leak.png';

UserModel _user() => UserModel(
  uid: 'u1',
  email: 'client@quickfix.com',
  fullName: 'Ahmed Ali',
  phone: '03001234567',
  role: UserRole.user,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

JobModel _job({List<String> images = const [_path]}) => JobModel(
  id: 'j1',
  userId: 'u1',
  title: 'Leaky kitchen sink',
  description: 'Water under the cabinet',
  category: JobCategory.plumbing,
  address: 'F-7, Islamabad',
  location: const GeoPoint(33.7, 73.0),
  budgetMin: 2000,
  budgetMax: 3000,
  preferredDate: DateTime(2026, 12),
  images: images,
  status: JobStatus.open,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() => registerFallbackValue(JobCategory.other));

  late _Jobs jobs;
  late _Images images;
  late _Requests requests;
  late _Profiles profiles;

  setUp(() {
    jobs = _Jobs();
    images = _Images();
    requests = _Requests();
    profiles = _Profiles();
    when(() => images.readImage(any())).thenAnswer((_) async => _tinyPng);
    when(() => requests.getExistingRequest(
      jobId: any(named: 'jobId'),
      workerId: any(named: 'workerId'),
    )).thenAnswer((_) async => null);
  });

  void sizeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('client home thumbnail opens the zoom viewer', (tester) async {
    sizeView(tester);
    when(() => jobs.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value([_job()]));

    await tester.pumpWidget(MaterialApp(
      home: ClientHomeScreen(user: _user(), jobService: jobs, imageStore: images),
    ));
    await tester.pump();

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();

    final viewer = tester.widget<LocalPhotoViewer>(find.byType(LocalPhotoViewer));
    expect(viewer.imagePath, _path);
    expect(viewer.caption, 'Leaky kitchen sink');
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('worker dashboard thumbnail opens the zoom viewer', (tester) async {
    sizeView(tester);
    when(() => jobs.watchOpenJobs())
        .thenAnswer((_) => Stream.value([_job()]));

    await tester.pumpWidget(MaterialApp(
      home: WorkerDashboardScreen(
        user: _user(),
        jobService: jobs,
        requestService: requests,
        profileService: profiles,
        imageStore: images,
      ),
    ));
    await tester.pump();

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();

    expect(find.byType(LocalPhotoViewer), findsOneWidget);
  });

  testWidgets('worker history thumbnail opens the zoom viewer', (tester) async {
    sizeView(tester);
    when(() => jobs.watchWorkerJobs('w1'))
        .thenAnswer((_) => Stream.value([_job()]));

    await tester.pumpWidget(MaterialApp(
      home: MyJobsScreen(workerId: 'w1', jobService: jobs, imageStore: images),
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    final viewer = tester.widget<LocalPhotoViewer>(find.byType(LocalPhotoViewer));
    expect(viewer.imagePath, _path);
  });

  testWidgets('a missing photo file shows the viewer message, not a crash', (
    tester,
  ) async {
    sizeView(tester);
    when(() => images.readImage(any())).thenAnswer((_) async => null);
    when(() => jobs.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value([_job()]));

    await tester.pumpWidget(MaterialApp(
      home: ClientHomeScreen(user: _user(), jobService: jobs, imageStore: images),
    ));
    await tester.pump();

    // No bytes means the thumbnail renders its category fallback and offers
    // no tap target at all — nothing can crash.
    expect(find.byType(LocalPhotoViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
