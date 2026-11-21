import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/status_pill.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/admin_account_detail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class AdminAccountDetailScreen extends StatefulWidget {
  final String uid;
  final bool worker;
  final UserModel user;
  final AdminService? adminService;
  const AdminAccountDetailScreen({super.key, required this.uid, this.worker = false, required this.user, this.adminService});
  @override
  State<AdminAccountDetailScreen> createState() => _AdminAccountDetailScreenState();
}

class _AdminAccountDetailScreenState extends State<AdminAccountDetailScreen> with SingleTickerProviderStateMixin {
  late final AdminService _service = widget.adminService ?? AdminService();
  late final TabController _tabs;
  late Future<AdminAccountDetail?> _detail = _service.accountDetail(widget.uid, worker: widget.worker);
  bool _busy = false;
  String? _error;
  final _note = TextEditingController();
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() { _tabs.dispose(); _note.dispose(); super.dispose(); }
  void _reload() => setState(() => _detail = _service.accountDetail(widget.uid, worker: widget.worker));

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Account review'), actions: const [Padding(padding: EdgeInsets.only(right: 14), child: AdminModeBadge())]), body: FutureBuilder<AdminAccountDetail?>(future: _detail, builder: (context, snapshot) {
    if (snapshot.hasError) return AdminError(onRetry: _reload);
    if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 5);
    final detail = snapshot.data;
    if (detail == null) return const AdminEmpty(title: 'Account not found', message: 'The profile may have been removed.');
    final row = detail.account;
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
        AdminCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          UserAvatar(fullName: row.name, avatarUrl: row.avatarUrl, size: 60), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.name.isEmpty ? 'Unnamed account' : row.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(row.email, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            Text((detail.userData['phone'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 4, children: [
              StatusPill(label: row.role, color: AppTheme.brandBlue),
              if (row.blocked) const StatusPill(label: 'Blocked', color: AppTheme.textMuted),
              if (widget.worker) StatusPill(label: row.approved ? 'Approved' : 'Not approved', color: row.approved ? AppTheme.successGreen : AppTheme.accentYellow),
              if (widget.worker) StatusPill(label: row.verificationStatus, color: adminStatusColor(row.verificationStatus)),
            ]),
            const SizedBox(height: 6), Text('Joined ${_joined(row.createdAt)} · UID ${row.uid}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ])),
        ])),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _stat('Rating', row.rating.toStringAsFixed(1))), const SizedBox(width: 10), Expanded(child: _stat('Completed jobs', '${row.completedJobs}')), const SizedBox(width: 10), Expanded(child: _stat('Recent jobs', '${detail.jobs.length}'))]),
        const SizedBox(height: 12),
        if (widget.worker) _verification(detail),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppTheme.dangerRed))),
      ])),
      Material(color: AppTheme.surfaceWhite, child: TabBar(controller: _tabs, tabs: const [Tab(text: 'Activity'), Tab(text: 'Reviews'), Tab(text: 'Moderation')], labelColor: AppTheme.brandBlue, indicatorColor: AppTheme.ctaOrange)),
      SizedBox(height: 250, child: TabBarView(controller: _tabs, children: [
        _activity(detail), _reviews(detail), _moderation(detail),
      ])),
    ]);
  }));

  Widget _stat(String label, String value) => AdminCard(padding: const EdgeInsets.all(10), child: Column(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))]));
  String _joined(DateTime? date) => date == null ? 'date unavailable' : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _activity(AdminAccountDetail detail) {
    if (detail.jobs.isEmpty) return const AdminEmpty(title: 'No recent jobs', message: 'No jobs are available for this account.');
    return ListView(padding: const EdgeInsets.all(14), children: detail.jobs.map((job) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdminCard(child: ListTile(leading: const Icon(Icons.work_outline), title: Text((job['title'] ?? 'Job').toString()), subtitle: Text('${job['status'] ?? 'unknown'} · ${(job['category'] ?? '').toString()}'))),
    )).toList());
  }

  Widget _reviews(AdminAccountDetail detail) {
    if (detail.reviews.isEmpty) return const AdminEmpty(title: 'No recent reviews', message: 'No reviews are available for this account.');
    return ListView(padding: const EdgeInsets.all(14), children: detail.reviews.map((review) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdminCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('★ ${(review['rating'] ?? 0).toString()}', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text((review['originalText'] ?? 'No review text').toString()),
      ])),
    )).toList());
  }

  Widget _moderation(AdminAccountDetail detail) {
    final row = detail.account;
    return ListView(padding: const EdgeInsets.all(14), children: [
      if (_busy) const LinearProgressIndicator(),
      if (!widget.worker) _actionButton(row.blocked ? 'Unblock account' : 'Block account', row.blocked ? Icons.lock_open : Icons.block, row.blocked ? AppTheme.brandBlue : AppTheme.dangerRed, () => _confirmAndRun(row.blocked ? 'Unblock ${row.name}?' : 'Block ${row.name}?', row.blocked ? 'This restores the account’s access.' : 'This suspends this account from signing in.', () => _service.setUserBlocked(widget.uid, !row.blocked))),
      if (widget.worker) ...[
        _actionButton(row.blocked ? 'Unblock worker' : 'Block worker', Icons.block, row.blocked ? AppTheme.brandBlue : AppTheme.dangerRed, () => _confirmAndRun(row.blocked ? 'Unblock ${row.name}?' : 'Block ${row.name}?', 'Blocking hides this worker from browse and blocks quotes.', () => _service.setWorkerBlocked(widget.uid, !row.blocked))),
        _actionButton(row.approved ? 'Revoke approval' : 'Approve worker', Icons.verified_outlined, row.approved ? AppTheme.textMuted : AppTheme.successGreen, () => _confirmAndRun(row.approved ? 'Revoke approval for ${row.name}?' : 'Approve ${row.name}?', 'This changes worker approval status.', () => _service.setWorkerApproved(widget.uid, !row.approved))),
        if (detail.verification?['status'] == 'pending') ...[
          TextField(controller: _note, key: const Key('admin-verification-note'), maxLines: 2, decoration: const InputDecoration(labelText: 'Verification note', hintText: 'Required for rejection')),
          const SizedBox(height: 8),
          Text('Proof photos are device-local paths and cannot be viewed on this administrator device. Verify through a separate secure or in-person channel before approval.', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          _actionButton('Approve verification', Icons.verified, AppTheme.successGreen, () => _confirmAndRun('Approve verification for ${row.name}?', 'Confirm you completed a separate secure or in-person identity check. The local proof photos are not available here.', () => _service.reviewVerification(widget.uid, 'verified', note: _note.text))),
          _actionButton('Reject verification', Icons.cancel_outlined, AppTheme.textMuted, () => _confirmAndRun('Reject verification for ${row.name}?', 'The worker will need to submit verification again. Add a reason in the note field.', () => _service.reviewVerification(widget.uid, 'rejected', note: _note.text))),
        ],
      ],
    ]);
  }

  Widget _verification(AdminAccountDetail detail) {
    final verification = detail.verification;
    if (verification == null) return const AdminCard(child: Text('No verification request is available.'));
    final status = (verification['status'] ?? 'notStarted').toString();
    return AdminCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Worker verification', style: TextStyle(fontWeight: FontWeight.w700))), StatusPill(label: status, color: adminStatusColor(status))]),
      const SizedBox(height: 8), Text('Front: ${verification['cnicFrontPath'] == null ? 'not supplied' : 'submitted locally'}'),
      Text('Back: ${verification['cnicBackPath'] == null ? 'not supplied' : 'submitted locally'}'),
      Text('Selfie: ${verification['selfiePath'] == null ? 'not supplied' : 'submitted locally'}'),
      if ((verification['note'] ?? '').toString().isNotEmpty) Text('Note: ${verification['note']}'),
    ]));
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onPressed) => Padding(padding: const EdgeInsets.only(bottom: 8), child: OutlinedButton.icon(onPressed: _busy ? null : onPressed, icon: Icon(icon, color: color), label: Text(label, style: TextStyle(color: color))));

  Future<void> _confirmAndRun(String title, String consequence, Future<void> Function() action) async {
    final confirmed = await showModalBottomSheet<bool>(context: context, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(consequence), const SizedBox(height: 16),
      ElevatedButton(key: const Key('admin-account-confirm-action'), onPressed: () => Navigator.pop(sheetContext, true), child: const Text('Confirm action')),
      TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: const Text('Cancel')),
    ]))));
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try { await action(); if (!mounted) return; setState(() { _busy = false; _detail = _service.accountDetail(widget.uid, worker: widget.worker); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account moderation updated.'))); }
    catch (error) { if (mounted) setState(() { _busy = false; _error = error.toString(); }); }
  }
}
