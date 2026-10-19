import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/notification_service.dart';
import 'package:quickfix/views/notifications/notifications_screen.dart';
class MockNotifications extends Mock implements NotificationService {}
void main() {
  late MockNotifications service;
  final user = UserModel(uid: 'u', email: '', fullName: 'Client', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
  setUp(() { service = MockNotifications(); when(() => service.watchItems('u')).thenAnswer((_) => Stream.value([])); when(() => service.markAllRead('u')).thenAnswer((_) async {}); when(() => service.markRead('u', 'n')).thenAnswer((_) async {}); });
  Future<void> pump(WidgetTester tester) async { await tester.pumpWidget(MaterialApp(home: NotificationsScreen(user: user, notificationService: service))); await tester.pump(); }
  testWidgets('loading and actionable empty states', (tester) async {
    final stream = StreamController<List<AppNotification>>(); addTearDown(stream.close); when(() => service.watchItems('u')).thenAnswer((_) => stream.stream);
    await pump(tester); expect(find.byType(LoadingList), findsOneWidget); stream.add([]); await tester.pumpAndSettle(); expect(find.text('You’re all caught up'), findsOneWidget); expect(find.text('Check again'), findsOneWidget);
  });
  testWidgets('stream error retries a new subscription', (tester) async {
    when(() => service.watchItems('u')).thenAnswer((_) => Stream.error(StateError('offline'))); await pump(tester); await tester.pump();
    when(() => service.watchItems('u')).thenAnswer((_) => Stream.value([])); await tester.tap(find.text('Retry')); await tester.pumpAndSettle(); expect(find.text('You’re all caught up'), findsOneWidget);
  });
  testWidgets('mark all awaits the service and exposes failures without false success', (tester) async {
    when(() => service.markAllRead('u')).thenThrow(StateError('partial')); await pump(tester);
    await tester.tap(find.byKey(const Key('notifications-all-read'))); await tester.pumpAndSettle(); expect(find.textContaining('Some may be saved'), findsOneWidget);
    when(() => service.markAllRead('u')).thenAnswer((_) async {}); await tester.tap(find.byKey(const Key('notifications-all-read'))); await tester.pumpAndSettle(); verify(() => service.markAllRead('u')).called(2);
  });
  testWidgets('RTL content and unavailable destination are handled without a fake route', (tester) async {
    when(() => service.watchItems('u')).thenAnswer((_) => Stream.value([AppNotification(id: 'n', userId: 'u', type: 'unknown', title: 'نئی اطلاع', body: 'تفصیل', refId: 'gone', createdAt: DateTime.now())]));
    await pump(tester); await tester.pumpAndSettle(); expect(tester.widget<Text>(find.text('نئی اطلاع')).textDirection, TextDirection.rtl);
    await tester.tap(find.byKey(const Key('notification-n'))); await tester.pumpAndSettle(); verify(() => service.markRead('u', 'n')).called(1);
    expect(find.textContaining('no available destination'), findsOneWidget);
  });
}
