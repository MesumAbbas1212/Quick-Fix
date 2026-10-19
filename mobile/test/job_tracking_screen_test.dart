import 'helpers/visible.dart' as test_viewport;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/shared_location.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
import 'package:quickfix/views/payments/payment_screen.dart';

class MockJobs extends Mock implements JobService {}
class MockProfiles extends Mock implements ProfileService {}
class MockAuth extends Mock implements AuthService {}
class MockChat extends Mock implements ChatService {}
class MockLauncher extends Mock implements UrlLauncher {}
class MockPayments extends Mock implements PaymentService {}
final _assigned = DateTime(2026, 10, 17, 10);
JobModel _job({JobStatus status = JobStatus.assigned, String? worker = 'w1', DateTime? assigned}) => JobModel(
  id: 'j1', userId: 'me', workerId: worker, title: 'مرمت کا کام', description: 'Fix the tap',
  category: JobCategory.plumbing, address: 'اٹک، پاکستان', location: const GeoPoint(33.77, 72.36),
  budgetMin: 1000, budgetMax: 2000, preferredDate: DateTime(2026, 10, 18), status: status,
  assignedAt: status == JobStatus.open ? null : assigned ?? _assigned, completedAt: status == JobStatus.completed ? DateTime(2026, 10, 18, 15) : null,
  createdAt: DateTime(2026, 10, 15), updatedAt: DateTime(2026, 10, 18));
WorkerProfile _worker({String name = 'احمد خان', String? phone = '+92 300 1234567'}) => WorkerProfile(
  uid: 'w1', fullName: name, email: 'worker@example.com', phone: phone,
  createdAt: DateTime(2026), updatedAt: DateTime(2026));

void main() {
  late MockJobs jobs;
  late MockProfiles profiles;
  late MockAuth auth;
  late MockChat chat;
  late MockLauncher launcher;
  late MockPayments payments;
  final location = SharedLocation(messageId: 'loc', latitude: 33.6, longitude: 72.5,
    sharedAt: DateTime(2026, 10, 18, 12));
  setUpAll(() {
    registerFallbackValue(JobStatus.assigned);
    registerFallbackValue(DateTime(2026));
  });
  setUp(() {
    jobs = MockJobs(); profiles = MockProfiles(); auth = MockAuth(); chat = MockChat();
    launcher = MockLauncher(); payments = MockPayments();
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(_job()));
    when(() => profiles.watchWorkerProfile('w1')).thenAnswer((_) => Stream.value(_worker()));
    when(() => auth.watchUser('me')).thenAnswer((_) => Stream.value(UserModel(
      uid: 'me', fullName: 'Client Name', email: 'client@example.com', phone: '03001234567',
      role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026))));
    when(() => chat.watchLatestSharedLocation(any(), any(), senderId: any(named: 'senderId'), since: any(named: 'since')))
      .thenAnswer((_) => Stream<SharedLocation?>.value(null));
    when(() => launcher.open(any())).thenAnswer((_) async => true);
    when(() => launcher.openLocation(any(), any())).thenAnswer((_) async => true);
    when(() => jobs.advanceJobStatus(jobId: any(named: 'jobId'), workerId: any(named: 'workerId'), status: any(named: 'status')))
      .thenAnswer((_) async {});
    when(() => jobs.cancelAssignedJob(any(), any())).thenAnswer((_) async {});
    when(() => chat.watchMessages(user1: any(named: 'user1'), user2: any(named: 'user2')))
      .thenAnswer((_) => Stream.value(<ChatMessage>[]));
    when(() => payments.getPaidPaymentForJob('j1')).thenAnswer((_) async => null);
  });
  Future<void> pump(WidgetTester tester, {String myId = 'me', bool settle = true, Size size = const Size(500, 1700), double scale = 1}) async {
    tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme,
      home: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: JobTrackingScreen(jobId: 'j1', myId: myId, jobService: jobs, profileService: profiles,
          authService: auth, chatService: chat, urlLauncher: launcher, paymentService: payments))));
    if (settle) { await tester.pumpAndSettle(); } else { await tester.pump(); }
  }
  void shared(Stream<SharedLocation?> stream) {
    when(() => chat.watchLatestSharedLocation(any(), any(), senderId: any(named: 'senderId'), since: any(named: 'since')))
      .thenAnswer((_) => stream);
  }
  testWidgets('shows skeleton while job stream is waiting', (tester) async {
    final stream = StreamController<JobModel?>(); addTearDown(stream.close);
    when(() => jobs.watchJob('j1')).thenAnswer((_) => stream.stream);
    await pump(tester, settle: false);
    expect(find.byType(LoadingList), findsOneWidget);
  });
  testWidgets('missing job is an actionable empty state, not an infinite spinner', (tester) async {
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(null));
    await pump(tester);
    expect(find.text('Job unavailable'), findsOneWidget);
    expect(find.text('Reload job'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('job error Retry creates a fresh subscription', (tester) async {
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.error(StateError('offline')));
    await pump(tester);
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(_job()));
    await tester.tap(find.byKey(const Key('error-retry-button'))); await tester.pumpAndSettle();
    expect(find.text('مرمت کا کام'), findsOneWidget);
    verify(() => jobs.watchJob('j1')).called(2);
  });
  testWidgets('a nonparticipant cannot see contacts, location or actions', (tester) async {
    await pump(tester, myId: 'stranger');
    expect(find.textContaining('only available to the client'), findsOneWidget);
    expect(find.byKey(const Key('tracking-chat-button')), findsNothing);
    verifyNever(() => profiles.watchWorkerProfile(any()));
    verifyNever(() => chat.watchLatestSharedLocation(any(), any(), senderId: any(named: 'senderId'), since: any(named: 'since')));
  });
  testWidgets('renders all four stages and honest no-location copy', (tester) async {
    await pump(tester);
    for (final text in ['Accepted', 'On the way', 'In progress', 'Completed']) {
      expect(find.text(text), findsWidgets);
    }
    expect(find.textContaining('No location shared yet.'), findsOneWidget);
    expect(find.byKey(const Key('tracking-shared-maps')), findsNothing);
    expect(find.byKey(const Key('tracking-worker-action')), findsNothing);
    verify(() => chat.watchLatestSharedLocation('me', 'w1', senderId: 'w1', since: _assigned)).called(1);
  });
  testWidgets('shared and job map actions open different coordinates', (tester) async {
    shared(Stream.value(location)); await pump(tester);
    await tester.tap(find.byKey(const Key('tracking-job-maps'))); await tester.pump();
    await test_viewport.reveal(tester, find.byKey(const Key('tracking-shared-maps')));
    await tester.tap(find.byKey(const Key('tracking-shared-maps'))); await tester.pump();
    verify(() => launcher.openLocation(33.77, 72.36)).called(1);
    verify(() => launcher.openLocation(33.6, 72.5)).called(1);
    expect(find.text('Location shared, not a travel confirmation'), findsOneWidget);
  });
  testWidgets('map failures are visible rather than swallowed', (tester) async {
    when(() => launcher.openLocation(any(), any())).thenAnswer((_) async => false);
    await pump(tester); await tester.tap(find.byKey(const Key('tracking-job-maps'))); await tester.pump();
    expect(find.text('Could not open Maps.'), findsOneWidget);
  });
  testWidgets('Call opens a sanitized tel URL', (tester) async {
    await pump(tester); await tester.tap(find.byKey(const Key('tracking-call-button'))); await tester.pump();
    verify(() => launcher.open('tel:+923001234567')).called(1);
  });
  testWidgets('phone-less profiles show a disabled Call button', (tester) async {
    when(() => profiles.watchWorkerProfile('w1')).thenAnswer((_) => Stream.value(_worker(phone: null)));
    await pump(tester);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('tracking-call-button'))).onPressed, isNull);
    expect(find.text('Phone number not provided'), findsOneWidget);
  });
  testWidgets('Chat opens the real page with participant ids and injected service', (tester) async {
    await pump(tester); await tester.tap(find.byKey(const Key('tracking-chat-button'))); await tester.pumpAndSettle();
    final page = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(page.myId, 'me'); expect(page.peerId, 'w1'); expect(page.chatService, same(chat));
  });
  testWidgets('contact updates are live and do not resubscribe the job', (tester) async {
    final stream = StreamController<WorkerProfile?>(); addTearDown(stream.close);
    when(() => profiles.watchWorkerProfile('w1')).thenAnswer((_) => stream.stream);
    await pump(tester);
    stream.add(_worker(name: 'Updated Worker')); await tester.pumpAndSettle();
    expect(find.text('Updated Worker'), findsOneWidget);
    verify(() => jobs.watchJob('j1')).called(1);
  });
  testWidgets('contact Retry renews the profile stream', (tester) async {
    when(() => profiles.watchWorkerProfile('w1')).thenAnswer((_) => Stream.error(StateError('offline')));
    await pump(tester);
    when(() => profiles.watchWorkerProfile('w1')).thenAnswer((_) => Stream.value(_worker()));
    await tester.tap(find.byKey(const Key('tracking-contact-retry'))); await tester.pumpAndSettle();
    expect(find.text('احمد خان'), findsOneWidget);
    verify(() => profiles.watchWorkerProfile('w1')).called(2);
  });
  testWidgets('location Retry renews the location stream', (tester) async {
    shared(Stream.error(StateError('offline'))); await pump(tester);
    shared(Stream.value(location)); await tester.tap(find.byKey(const Key('tracking-location-retry'))); await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking-shared-maps')), findsOneWidget);
    verify(() => chat.watchLatestSharedLocation('me', 'w1', senderId: 'w1', since: _assigned)).called(2);
  });
  testWidgets('worker sees client contact and start action, never cancel or pay', (tester) async {
    await pump(tester, myId: 'w1');
    expect(find.text('Client Name'), findsOneWidget);
    expect(find.byKey(const Key('tracking-worker-action')), findsOneWidget);
    expect(find.byKey(const Key('tracking-cancel-button')), findsNothing);
    expect(find.byKey(const Key('tracking-payment-button')), findsNothing);
    await tester.tap(find.byKey(const Key('tracking-worker-action'))); await tester.pumpAndSettle();
    verify(() => jobs.advanceJobStatus(jobId: 'j1', workerId: 'w1', status: JobStatus.inProgress)).called(1);
    verify(() => chat.watchLatestSharedLocation('w1', 'me', senderId: 'me', since: _assigned)).called(1);
  });
  testWidgets('status action disables duplicate taps while saving', (tester) async {
    final saved = Completer<void>();
    when(() => jobs.advanceJobStatus(jobId: 'j1', workerId: 'w1', status: JobStatus.inProgress)).thenAnswer((_) => saved.future);
    await pump(tester, myId: 'w1'); await tester.tap(find.byKey(const Key('tracking-worker-action'))); await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('tracking-worker-action'))).onPressed, isNull);
    saved.complete(); await tester.pumpAndSettle();
    verify(() => jobs.advanceJobStatus(jobId: 'j1', workerId: 'w1', status: JobStatus.inProgress)).called(1);
  });
  testWidgets('worker completion requires confirmation', (tester) async {
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(_job(status: JobStatus.inProgress)));
    await pump(tester, myId: 'w1'); await tester.tap(find.byKey(const Key('tracking-worker-action'))); await tester.pumpAndSettle();
    verifyNever(() => jobs.advanceJobStatus(jobId: 'j1', workerId: 'w1', status: JobStatus.completed));
    await tester.tap(find.byKey(const Key('tracking-confirm-action'))); await tester.pumpAndSettle();
    verify(() => jobs.advanceJobStatus(jobId: 'j1', workerId: 'w1', status: JobStatus.completed)).called(1);
  });
  testWidgets('client cancellation can be dismissed, then explicitly confirmed', (tester) async {
    await pump(tester); await tester.tap(find.byKey(const Key('tracking-cancel-button'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Not now')); await tester.pumpAndSettle();
    verifyNever(() => jobs.cancelAssignedJob(any(), any()));
    await tester.tap(find.byKey(const Key('tracking-cancel-button'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tracking-confirm-action'))); await tester.pumpAndSettle();
    verify(() => jobs.cancelAssignedJob('j1', 'me')).called(1);
  });
  testWidgets('failed write shows a useful error and restores controls', (tester) async {
    when(() => jobs.advanceJobStatus(jobId: 'j1', workerId: 'w1', status: JobStatus.inProgress)).thenThrow(StateError('offline'));
    await pump(tester, myId: 'w1'); await tester.tap(find.byKey(const Key('tracking-worker-action'))); await tester.pumpAndSettle();
    expect(find.textContaining('Could not update the job.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('tracking-worker-action'))).onPressed, isNotNull);
  });
  testWidgets('live completion hides client cancel and enables the real payment page', (tester) async {
    final stream = StreamController<JobModel?>.broadcast(); addTearDown(stream.close);
    when(() => jobs.watchJob('j1')).thenAnswer((_) => stream.stream);
    await pump(tester); stream.add(_job(status: JobStatus.completed)); await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking-cancel-button')), findsNothing);
    await tester.tap(find.byKey(const Key('tracking-payment-button'))); await tester.pump();
    stream.add(_job(status: JobStatus.completed)); await tester.pumpAndSettle();
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(tester.widget<PaymentScreen>(find.byType(PaymentScreen)).paymentService, same(payments));
    await tester.pumpWidget(const SizedBox()); // Unsubscribe before closing the broadcast stream.
  });
  testWidgets('cancelled jobs have no progression, cancel or payment CTA', (tester) async {
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(_job(status: JobStatus.cancelled)));
    await pump(tester);
    expect(find.byKey(const Key('tracking-worker-action')), findsNothing);
    expect(find.byKey(const Key('tracking-cancel-button')), findsNothing);
    expect(find.byKey(const Key('tracking-payment-button')), findsNothing);
    expect(find.textContaining('This job is cancelled.'), findsOneWidget);
  });
  testWidgets('unassigned job has an actionable waiting state', (tester) async {
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(_job(worker: null, status: JobStatus.open)));
    await pump(tester);
    expect(find.text('Waiting for assignment'), findsOneWidget);
    expect(find.text('Check assignment'), findsOneWidget);
    verifyNever(() => profiles.watchWorkerProfile(any()));
  });
  testWidgets('Urdu content is RTL while narrow enlarged English UI stays usable', (tester) async {
    shared(Stream.value(location)); await pump(tester, size: const Size(320, 900), scale: 1.5);
    expect(tester.widget<Text>(find.text('مرمت کا کام')).textDirection, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
  testWidgets('anonymized history has no map, chat, contact or pay action', (tester) async {
    when(() => jobs.watchJob('j1')).thenAnswer((_) => Stream.value(_job(status: JobStatus.completed, worker: 'deleted-account').copyWith(anonymized: true)));
    await pump(tester); expect(find.text('Completed job — anonymized history'), findsOneWidget);
    expect(find.byKey(const Key('tracking-job-maps')), findsNothing); expect(find.byKey(const Key('tracking-payment-button')), findsNothing);
    verifyNever(() => profiles.watchWorkerProfile(any())); verifyNever(() => chat.watchLatestSharedLocation(any(), any(), senderId: any(named: 'senderId'), since: any(named: 'since')));
  });

}
