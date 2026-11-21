import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/status_pill.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_report_detail_screen.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class AdminReportsScreen extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  final AdminService? adminService;
  const AdminReportsScreen({super.key, required this.user, this.authService, this.adminService});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late final AdminService _service = widget.adminService ?? AdminService();
  String _filter = 'open';
  late Future<int> _openCount = _service.openReportsCount();
  @override
  Widget build(BuildContext context) => FutureBuilder<int>(future: _openCount, builder: (context, countSnapshot) {
    if (countSnapshot.hasError) return AdminError(onRetry: () => setState(() => _openCount = _service.openReportsCount()));
    if (!countSnapshot.hasData) return const AdminLoading(rows: 6);
    return StreamBuilder<List<AdminReportRow>>(
    stream: _service.watchReports(limit: 50),
    builder: (context, snapshot) {
      if (snapshot.hasError) return AdminError(onRetry: () => setState(() {}));
      if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 6);
      final all = snapshot.data ?? const <AdminReportRow>[];
      final openCount = countSnapshot.data!;
      final filtered = all.where((item) => item.status == _filter).toList();
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6), child: SegmentedButton<String>(
          key: const Key('admin-report-filter'),
          segments: [
            ButtonSegment(value: 'open', label: Text('Open ($openCount)')),
            const ButtonSegment(value: 'resolved', label: Text('Resolved')),
            const ButtonSegment(value: 'dismissed', label: Text('Dismissed')),
          ], selected: {_filter}, onSelectionChanged: (value) => setState(() => _filter = value.first),
        )),
        Expanded(child: filtered.isEmpty
          ? AdminEmpty(title: 'No $_filter reports', message: 'Reports matching this status will appear here.')
          : ListView.builder(padding: const EdgeInsets.all(14), itemCount: filtered.length, itemBuilder: (context, index) => _row(context, filtered[index]))),
      ]);
    },
  );
  });

  Widget _row(BuildContext context, AdminReportRow report) => Padding(padding: const EdgeInsets.only(bottom: 12), child: AdminCard(child: ListTile(
    key: Key('admin-report-row-${report.id}'), contentPadding: EdgeInsets.zero,
    title: Text(report.reason, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('${report.reporterName.isEmpty ? report.reporterId : report.reporterName} → ${report.reportedName.isEmpty ? report.reportedId : report.reportedName}\n${_age(report.createdAt)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
    trailing: StatusPill(label: report.status, color: adminStatusColor(report.status)),
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminReportDetailScreen(reportId: report.id, user: widget.user, adminService: _service))),
  )));

  String _age(DateTime? date) => date == null ? 'Date unavailable' : DateFormat.yMMMd().add_jm().format(date);
}
