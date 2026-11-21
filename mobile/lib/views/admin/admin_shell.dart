import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/admin_catalog_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/admin/admin_dashboard_screen.dart';
import 'package:quickfix/views/admin/admin_reports_screen.dart';
import 'package:quickfix/views/admin/admin_accounts_screen.dart';
import 'package:quickfix/views/admin/admin_catalog_screen.dart';
import 'package:quickfix/views/admin/admin_profile_screen.dart';

class AdminShell extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  final AdminService? adminService;
  final AdminCatalogService? catalogService;
  const AdminShell({super.key, required this.user, this.authService, this.adminService, this.catalogService});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  late final AuthService _auth = widget.authService ?? AuthService();
  final PageController _pages = PageController();
  int _tab = 0;
  bool _checkingResume = false;
  bool _leaving = false;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _pages.dispose(); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifyCurrentRole();
  }

  Future<void> _verifyCurrentRole() async {
    if (_checkingResume || _leaving) return;
    setState(() => _checkingResume = true);
    try {
      final profile = await _auth.getUserProfile(widget.user.uid, serverOnly: true).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (profile == null || profile.role != UserRole.admin || profile.blocked) {
        await _failClosed();
        return;
      }
      setState(() => _checkingResume = false);
    } catch (_) {
      // Admin data is not shown when the role cannot be re-verified.
      await _failClosed();
    }
  }

  Future<void> _failClosed() async {
    if (_leaving) return;
    _leaving = true;
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _select(int index) { setState(() => _tab = index); _pages.jumpToPage(index); }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _auth.watchUser(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) { scheduleMicrotask(_failClosed); return const _AdminGateLoading(); }
        final current = snapshot.data;
        if (snapshot.connectionState != ConnectionState.waiting &&
            (current == null || current.role != UserRole.admin || current.blocked)) {
          scheduleMicrotask(_failClosed);
          return const _AdminGateLoading();
        }
        if (_checkingResume || current == null) return const _AdminGateLoading();
        return Scaffold(
          backgroundColor: AppTheme.bgLight,
          appBar: AppBar(title: const Text('QuickFix'), actions: const [Padding(padding: EdgeInsets.only(right: 14), child: _AdminChip())]),
          body: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _KeepAlive(AdminDashboardScreen(user: current, authService: _auth, adminService: widget.adminService, onOpenReports: () => _select(1), onOpenAccounts: () => _select(2))),
              _KeepAlive(AdminReportsScreen(user: current, authService: _auth, adminService: widget.adminService)),
              _KeepAlive(AdminAccountsScreen(user: current, authService: _auth, adminService: widget.adminService)),
              _KeepAlive(AdminCatalogScreen(user: current, authService: _auth, catalogService: widget.catalogService)),
              _KeepAlive(AdminProfileScreen(user: current, authService: _auth)),
            ],
          ),
          bottomNavigationBar: SafeArea(top: false, child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: _select,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
              BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), label: 'Reports'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Accounts'),
              BottomNavigationBarItem(icon: Icon(Icons.category_outlined), label: 'Catalog'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          )),
        );
      },
    );
  }
}

class _AdminChip extends StatelessWidget {
  const _AdminChip();
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('admin-mode-chip'),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: AppTheme.brandBlue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
    child: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.brandBlue)),
  );
}

class _AdminGateLoading extends StatelessWidget {
  const _AdminGateLoading();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive(this.child);
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}
class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) { super.build(context); return widget.child; }
}
