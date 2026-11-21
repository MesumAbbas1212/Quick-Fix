import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/status_pill.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_account_detail_screen.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final String reportId;
  final UserModel user;
  final AdminService? adminService;
  const AdminReportDetailScreen({super.key, required this.reportId, required this.user, this.adminService});
  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  late final AdminService _service = widget.adminService ?? AdminService();
  late Future<AdminReportDetail?> _detail = _service.reportDetail(widget.reportId);
  final _note = TextEditingController();
  bool _submitting = false;
  String? _actionError;
  @override
  void dispose() { _note.dispose(); super.dispose(); }

  void _retry() => setState(() { _detail = _service.reportDetail(widget.reportId); });

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Report review'), actions: const [Padding(padding: EdgeInsets.only(right: 14), child: AdminModeBadge())]), body: FutureBuilder<AdminReportDetail?>(future: _detail, builder: (context, snapshot) {
    if (snapshot.hasError) return AdminError(onRetry: _retry);
    if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 4);
    final detail = snapshot.data;
    if (detail == null) return const AdminEmpty(title: 'Report not found', message: 'It may have been removed. Return to the reports queue.');
    final report = detail.report;
    final decided = report.status != 'open';
    return ListView(padding: const EdgeInsets.all(14), children: [
      AdminCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(report.reason, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), StatusPill(label: report.status, color: adminStatusColor(report.status))]),
        const SizedBox(height: 10), Text(report.details.isEmpty ? 'No additional details provided.' : report.details, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8), Text('Report ID: ${report.id}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        if (detail.reported['rating'] != null) Text('Worker rating: ${(detail.reported['rating'] as num).toStringAsFixed(1)} · completed jobs: ${detail.reported['completedJobs'] ?? 0}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        Text('Prior reports involving this account: ${detail.priorReportCount}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ])),
      const SizedBox(height: 14), const AdminSectionTitle('People involved'), const SizedBox(height: 8),
      _personCard(context, 'Reporter', report.reporterId, detail.reporter),
      const SizedBox(height: 10), _personCard(context, 'Reported account', report.reportedId, detail.reported),
      if (detail.job != null) ...[
        const SizedBox(height: 14), const AdminSectionTitle('Linked job'), const SizedBox(height: 8),
        AdminCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.work_outline, color: AppTheme.brandBlue), title: Text((detail.job!['title'] ?? 'Job').toString()), subtitle: Text('Status: ${(detail.job!['status'] ?? 'unknown').toString()}'))),
      ],
      if (detail.recentReviews.isNotEmpty) ...[
        const SizedBox(height: 14), const AdminSectionTitle('Recent review evidence'), const SizedBox(height: 8),
        ...detail.recentReviews.map((review) => Padding(padding: const EdgeInsets.only(bottom: 8), child: AdminCard(child: Text((review['originalText'] ?? '').toString(), style: const TextStyle(fontSize: 14))))),
      ],
      const SizedBox(height: 16), const AdminSectionTitle('Decision'), const SizedBox(height: 8),
      AdminCard(child: decided ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This report is already ${report.status}; no further decision is available.', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (report.resolutionNote.isNotEmpty) ...[const SizedBox(height: 8), Text(report.resolutionNote)],
        if (report.resolvedBy.isNotEmpty) Text('Reviewed by ${report.resolvedBy}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(key: const Key('admin-report-resolution-note'), controller: _note, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Resolution note', hintText: 'Required to resolve; optional to dismiss')),
        if (_actionError != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_actionError!, style: const TextStyle(color: AppTheme.dangerRed))),
        if (_submitting) const Center(child: CircularProgressIndicator()) else Row(children: [
          Expanded(child: ElevatedButton(key: const Key('admin-report-resolve'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen), onPressed: () => _submit('resolved'), child: const Text('Resolve'))),
          const SizedBox(width: 10), Expanded(child: OutlinedButton(key: const Key('admin-report-dismiss'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMuted, side: const BorderSide(color: AppTheme.borderGray)), onPressed: () => _submit('dismissed'), child: const Text('Dismiss'))),
        ]),
      ])),
    ]);
  }));

  Widget _personCard(BuildContext context, String label, String uid, Map<String, dynamic> data) => AdminCard(child: ListTile(
    contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_outline, color: AppTheme.brandBlue),
    title: Text('$label · ${(data['fullName'] ?? 'Unknown account').toString()}'), subtitle: Text('${data['email'] ?? uid}'),
    trailing: const Icon(Icons.chevron_right), onTap: uid.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminAccountDetailScreen(uid: uid, worker: data['role'] == 'worker', user: widget.user, adminService: _service))),
  ));

  Future<void> _submit(String status) async {
    if (status == 'resolved' && _note.text.trim().isEmpty) { setState(() => _actionError = 'Add a resolution note before resolving.'); return; }
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(status == 'resolved' ? 'Resolve this report?' : 'Dismiss this report?'),
      content: Text(status == 'resolved' ? 'This closes the report and any matching linked dispute.' : 'This marks the report as dismissed and closes any matching linked dispute.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), ElevatedButton(key: const Key('admin-report-confirm'), onPressed: () => Navigator.pop(dialogContext, true), child: Text(status == 'resolved' ? 'Resolve' : 'Dismiss'))],
    ));
    if (accepted != true || !mounted) return;
    setState(() { _submitting = true; _actionError = null; });
    try {
      await _service.resolveReport(reportId: widget.reportId, status: status, note: _note.text, resolvedBy: widget.user.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report decision saved.')));
    } catch (error) {
      if (mounted) setState(() { _submitting = false; _actionError = error.toString(); });
    }
  }
}
