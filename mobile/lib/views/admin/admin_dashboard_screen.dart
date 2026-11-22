import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/status_pill.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/admin_counts.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';
import 'package:quickfix/views/admin/admin_report_detail_screen.dart';
import 'package:quickfix/views/admin/admin_jobs_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  final AdminService? adminService;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenAccounts;
  const AdminDashboardScreen({super.key, required this.user, this.authService, this.adminService, this.onOpenReports, this.onOpenAccounts});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminService _service = widget.adminService ?? AdminService();
  late Future<AdminCounts> _counts = _service.counts();
  void _retry() => setState(() { _counts = _service.counts(); });

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
    FutureBuilder<AdminCounts>(future: _counts, builder: (context, snapshot) {
      if (snapshot.hasError) return SizedBox(height: 250, child: AdminError(onRetry: _retry));
      if (!snapshot.hasData) return _countsLoading();
      final counts = snapshot.data!;
      return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.65, crossAxisSpacing: 12, mainAxisSpacing: 12,
        children: [
          _stat('Users', counts.users, Icons.person_outline),
          _stat('Workers', counts.workers, Icons.handyman_outlined),
          _stat('Jobs', counts.jobs, Icons.work_outline, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminJobsScreen(user: widget.user, adminService: _service)))),
          _stat('Open reports', counts.openReports, Icons.flag_outlined),
        ]);
    }),
    const SizedBox(height: 20),
    Row(children: [const Expanded(child: AdminSectionTitle('Needs attention')), TextButton(onPressed: widget.onOpenReports, child: const Text('View reports'))]),
    StreamBuilder<List<AdminReportRow>>(stream: _service.watchReports(limit: 50), builder: (context, snapshot) {
      if (snapshot.hasError) return AdminError(onRetry: () => setState(() {}));
      if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 2);
      final open = (snapshot.data ?? const <AdminReportRow>[]).where((row) => row.status == 'open').take(5).toList();
      if (open.isEmpty) return const AdminCard(child: Text('No open reports currently.', style: TextStyle(color: AppTheme.textMuted)));
      return Column(children: open.map((report) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _reportTile(context, report))).toList());
    }),
    const SizedBox(height: 16),
    StreamBuilder<List<AdminAccountRow>>(stream: _service.watchPendingVerifications(limit: 5), builder: (context, snapshot) {
      if (snapshot.hasError) return AdminError(onRetry: () => setState(() {}));
      if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
      final pending = (snapshot.data ?? const <AdminAccountRow>[]).where((row) => row.verificationStatus == 'pending').take(5).toList();
      if (pending.isEmpty) return const SizedBox.shrink();
      return AdminCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text('Pending verifications', style: TextStyle(fontWeight: FontWeight.w700))), TextButton(onPressed: widget.onOpenAccounts, child: Text('${pending.length} · View'))]),
        ...pending.map((row) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.verified_user_outlined, color: AppTheme.accentYellow), title: Text(row.name.isEmpty ? row.uid : row.name), subtitle: Text(row.email), trailing: const StatusPill(label: 'Pending', color: AppTheme.accentYellow), onTap: widget.onOpenAccounts)),
      ]));
    }),
    const SizedBox(height: 20), const AdminSectionTitle('Recent activity'), const SizedBox(height: 10),
    StreamBuilder<List<AdminReportRow>>(stream: _service.watchReports(limit: 5), builder: (context, snapshot) {
      if (snapshot.hasError) return AdminError(onRetry: () => setState(() {}));
      if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 2);
      final rows = snapshot.data ?? const <AdminReportRow>[];
      if (rows.isEmpty) return const AdminEmpty(title: 'No recent activity', message: 'New reports will appear here.');
      return Column(children: rows.map((row) => _reportTile(context, row)).toList());
    }),
  ]);

  Widget _countsLoading() => GridView.count(key: const Key('admin-dashboard-count-skeleton'), shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.65, crossAxisSpacing: 12, mainAxisSpacing: 12, children: List.generate(4, (_) => const AdminCard(child: SizedBox(height: 62, child: Center(child: CircularProgressIndicator())))));

  Widget _stat(String label, int value, IconData icon, {VoidCallback? onTap}) {
    final contents = Row(children: [
      Icon(icon, color: AppTheme.brandBlue, size: 23), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark)), Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)])),
    ]);
    if (onTap == null) return AdminCard(child: contents);
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const Key('admin-dashboard-jobs-stat'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: contents),
        ),
      ),
    );
  }

  Widget _reportTile(BuildContext context, AdminReportRow report) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AdminCard(child: ListTile(
    key: Key('admin-dashboard-report-${report.id}'), contentPadding: EdgeInsets.zero,
    title: Text(report.reason, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text('${report.reporterName} → ${report.reportedName}', maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: StatusPill(label: report.status, color: adminStatusColor(report.status)),
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminReportDetailScreen(reportId: report.id, user: widget.user, adminService: _service))),
  )));
}
