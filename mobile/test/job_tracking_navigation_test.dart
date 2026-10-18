import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/shared_location.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/client/client_job_detail_screen.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';

class MockJobs extends Mock implements JobService {}
class MockProfiles extends Mock implements ProfileService {}
class MockAuth extends Mock implements AuthService {}
class MockChat extends Mock implements ChatService {}

void main() {
  late MockJobs jobs;
  late MockProfiles profiles;
  late MockAuth auth;
  late MockChat chat;
  final accepted = DateTime(2026, 10, 17);
  final job = JobModel(id: 'j1', userId: 'me', workerId: 'w1', title: 'Repair tap',
    description: 'Kitchen', category: JobCategory.plumbing, address: 'Attock',
    location: const GeoPoint(33.77, 72.36), budgetMin: 1000, budgetMax: 2000,
    preferredDate: DateTime(2026, 10, 18), status: JobStatus.assigned, assignedAt: accepted,
    createdAt: accepted, updatedAt: accepted);
  setUpAll(() { registerFallbackValue(DateTime(2026)); });
  setUp(() {
    jobs = MockJobs(); profiles = MockProfiles(); auth = MockAuth(); chat = MockChat();
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(job));
    when(() => jobs.watchWorkerJobs('w1')).thenAnswer((_) => Stream.value([job]));
    when(() => profiles.watchWorkerProfile('w1')).thenAnswer((_) => Stream.value(WorkerProfile(
      uid: 'w1', fullName: 'Ahmed', email: 'worker@example.com', createdAt: accepted, updatedAt: accepted)));
    when(() => auth.watchUser('me')).thenAnswer((_) => Stream.value(UserModel(uid: 'me',
      fullName: 'Client', email: 'client@example.com', phone: '', role: UserRole.user,
      createdAt: accepted, updatedAt: accepted)));
    when(() => chat.watchLatestSharedLocation(any(), any(), senderId: any(named: 'senderId'), since: any(named: 'since')))
      .thenAnswer((_) => Stream<SharedLocation?>.value(null));
  });
  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(600, 1400); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: page));
    await tester.pumpAndSettle();
  }
  testWidgets('client job detail opens tracking with existing job identity and injection', (tester) async {
    await pump(tester, ClientJobDetailScreen(job: job, currentUserId: 'me',
      jobService: jobs, profileService: profiles, authService: auth, chatService: chat));
    await tester.tap(find.byKey(const Key('client-job-tracking-button'))); await tester.pumpAndSettle();
    final page = tester.widget<JobTrackingScreen>(find.byType(JobTrackingScreen));
    expect(page.jobId, 'j1'); expect(page.myId, 'me'); expect(page.jobService, same(jobs));
    expect(page.chatService, same(chat));
  });
  testWidgets('worker My Jobs opens tracking without consuming legacy status actions', (tester) async {
    await pump(tester, MyJobsScreen(workerId: 'w1', jobService: jobs,
      profileService: profiles, authService: auth, chatService: chat));
    expect(find.text('Start Job'), findsOneWidget);
    await tester.tap(find.byKey(const Key('my-job-tracking-j1'))); await tester.pumpAndSettle();
    final page = tester.widget<JobTrackingScreen>(find.byType(JobTrackingScreen));
    expect(page.jobId, 'j1'); expect(page.myId, 'w1'); expect(page.authService, same(auth));
    expect(find.byKey(const Key('tracking-worker-action')), findsOneWidget);
  });
}
