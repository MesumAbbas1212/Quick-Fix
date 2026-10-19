import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/notification_service.dart';
import 'package:quickfix/views/notifications/notifications_screen.dart';

/// Mounted by each shell's home/header, not a push-notification permission.
class NotificationBell extends StatefulWidget {
  final UserModel user;
  final NotificationService? notificationService;
  final Color foregroundColor;
  const NotificationBell({super.key, required this.user, this.notificationService, this.foregroundColor = AppTheme.surfaceWhite});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}
class _NotificationBellState extends State<NotificationBell> {
  late final NotificationService _service = widget.notificationService ?? NotificationService();
  late Stream<List<AppNotification>> _stream = _watch();
  Stream<List<AppNotification>> _watch() { try { return _service.watchItems(widget.user.uid); } catch (error, stack) { return Stream.error(error, stack); } }
  @override
  void didUpdateWidget(covariant NotificationBell oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.user.uid != widget.user.uid) _stream = _watch(); }
  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppNotification>>(stream: _stream, builder: (context, snapshot) {
    final unread = NotificationService.unreadCount(snapshot.data ?? [], widget.user.notificationPrefs);
    return IconButton(key: const Key('notification-bell'), tooltip: snapshot.hasError ? 'Notifications — count unavailable' : !snapshot.hasData ? 'Notifications — loading count' : 'Notifications ($unread unread in latest 200)',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsScreen(user: widget.user, notificationService: _service))),
      icon: Badge(backgroundColor: AppTheme.ctaOrange, textColor: AppTheme.surfaceWhite, isLabelVisible: unread > 0 || snapshot.hasError, label: Text(snapshot.hasError ? '!' : unread > 99 ? '99+' : '$unread'),
        child: Icon(Icons.notifications_none_outlined, color: widget.foregroundColor)));
  });
}
