import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/status_pill.dart';
import 'package:quickfix/models/admin_job_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_account_detail_screen.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class AdminJobsScreen extends StatefulWidget {
  final UserModel user;
  final AdminService? adminService;
  const AdminJobsScreen({super.key, required this.user, this.adminService});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  late final AdminService _service = widget.adminService ?? AdminService();
  final TextEditingController _search = TextEditingController();
  late Stream<List<AdminJobRow>> _jobs = _service.watchJobs(limit: 50);
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _retry() => setState(() {
    _jobs = _service.watchJobs(limit: 50);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Jobs'),
      actions: const [
        Padding(padding: EdgeInsets.only(right: 14), child: AdminModeBadge()),
      ],
    ),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: TextField(
          key: const Key('admin-jobs-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search title or client',
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<AdminJobRow>>(
          stream: _jobs,
          builder: (context, snapshot) {
            if (snapshot.hasError) return AdminError(onRetry: _retry);
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AdminLoading(rows: 6);
            }
            final all = snapshot.data ?? const <AdminJobRow>[];
            final filtered = all.where(_matchesFilter).where(_matchesSearch).toList();
            return Column(children: [
              _filterBar(all),
              Expanded(child: filtered.isEmpty
                  ? AdminEmpty(
                      title: _search.text.trim().isNotEmpty
                          ? 'No search matches'
                          : _emptyTitle(_filter),
                      message: _search.text.trim().isNotEmpty
                          ? 'Try another job title or client name.'
                          : 'Jobs matching this status will appear here.',
                    )
                  : ListView.builder(
                      key: const Key('admin-jobs-list'),
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _jobCard(filtered[index]),
                    )),
            ]);
          },
        ),
      ),
    ]),
  );

  Widget _filterBar(List<AdminJobRow> jobs) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
    child: SizedBox(
      height: 42,
      child: ListView(
        key: const Key('admin-jobs-filters'),
        scrollDirection: Axis.horizontal,
        children: _filters.map((filter) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: Key('admin-jobs-filter-${filter.value}'),
            label: Text('${filter.label} (${_countForFilter(jobs, filter.value)})'),
            selected: _filter == filter.value,
            onSelected: (_) => setState(() => _filter = filter.value),
          ),
        )).toList(growable: false),
      ),
    ),
  );

  bool _matchesFilter(AdminJobRow job) => switch (_filter) {
    'all' => true,
    'open' => job.status == 'open' || job.status == 'pending',
    _ => job.status == _filter,
  };

  bool _matchesSearch(AdminJobRow job) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return job.title.toLowerCase().contains(query) ||
        job.clientName.toLowerCase().contains(query);
  }

  int _countForFilter(List<AdminJobRow> jobs, String filter) => jobs.where((job) {
    if (filter == 'all') return true;
    if (filter == 'open') return job.status == 'open' || job.status == 'pending';
    return job.status == filter;
  }).length;

  String _emptyTitle(String filter) => switch (filter) {
    'all' => 'No jobs found',
    'open' => 'No open jobs',
    'assigned' => 'No assigned jobs',
    'inProgress' => 'No jobs in progress',
    'completed' => 'No completed jobs',
    'cancelled' => 'No cancelled jobs',
    _ => 'No jobs found',
  };

  Widget _jobCard(AdminJobRow job) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AdminCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('admin-job-card-${job.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetails(job),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      job.title.isEmpty ? 'Untitled job' : job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(job.status),
                ]),
                const SizedBox(height: 7),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_categoryLabel(job.category)),
                ),
                Text(
                  'PKR ${_money.format(job.budgetMin)} – ${_money.format(job.budgetMax)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
                const SizedBox(height: 5),
                Text(
                  '${job.clientName.isEmpty ? 'Unknown client' : job.clientName} → ${job.workerName ?? 'Unassigned'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 3),
                Text(_relativeAge(job.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _showDetails(AdminJobRow job) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _JobDetailsSheet(
        job: job,
        user: widget.user,
        adminService: _service,
        onCancel: () => _cancelJob(sheetContext, job),
      ),
    );
  }

  Future<void> _cancelJob(BuildContext sheetContext, AdminJobRow job) async {
    if (job.status == 'completed' || job.status == 'cancelled') return;
    final reasonController = TextEditingController();
    String? reason;
    try {
      reason = await showDialog<String>(
        context: sheetContext,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Cancellation reason'),
            content: TextField(
              key: const Key('admin-cancel-job-reason'),
              controller: reasonController,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                hintText: 'Explain why this job must be cancelled',
              ),
              onChanged: (_) => setDialogState(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back'),
              ),
              ElevatedButton(
                key: const Key('admin-cancel-job-reason-submit'),
                onPressed: reasonController.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, reasonController.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      reasonController.dispose();
    }
    if (reason == null || reason.trim().isEmpty || !sheetContext.mounted) return;

    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel “${job.title}”?'),
        content: const Text(
          'This marks the job as cancelled and saves the reason. The job will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep job'),
          ),
          ElevatedButton(
            key: const Key('admin-cancel-job-confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm cancellation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !sheetContext.mounted) return;

    try {
      await _service.cancelJob(job.id, reason.trim());
      if (!mounted || !sheetContext.mounted) return;
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel job: $error')),
      );
    }
  }

  static final NumberFormat _money = NumberFormat('#,##0', 'en_PK');

  Widget _statusPill(String status) => StatusPill(
    label: _statusLabel(status),
    color: switch (status.toLowerCase()) {
      'open' || 'pending' => AppTheme.accentYellow,
      'completed' => AppTheme.successGreen,
      'cancelled' => AppTheme.dangerRed,
      _ => AppTheme.brandBlue,
    },
  );

  String _statusLabel(String status) => switch (status) {
    'inProgress' => 'In progress',
    _ => status.isEmpty ? 'Unknown' : '${status[0].toUpperCase()}${status.substring(1)}',
  };

  String _categoryLabel(String category) => category.isEmpty
      ? 'Other'
      : category.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}').replaceFirstMapped(
          RegExp(r'^[a-z]'),
          (match) => match[0]!.toUpperCase(),
        );

  String _relativeAge(DateTime date) {
    final delta = DateTime.now().difference(date);
    if (delta.isNegative || delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} hr ago';
    if (delta.inDays < 7) return '${delta.inDays} days ago';
    if (delta.inDays < 56) return '${delta.inDays ~/ 7} wk ago';
    return DateFormat('d MMM yyyy', 'en').format(date);
  }

  static const List<({String value, String label})> _filters = [
    (value: 'all', label: 'All'),
    (value: 'open', label: 'Open'),
    (value: 'assigned', label: 'Assigned'),
    (value: 'inProgress', label: 'In progress'),
    (value: 'completed', label: 'Completed'),
    (value: 'cancelled', label: 'Cancelled'),
  ];
}

class _JobDetailsSheet extends StatelessWidget {
  final AdminJobRow job;
  final UserModel user;
  final AdminService adminService;
  final VoidCallback onCancel;
  const _JobDetailsSheet({
    required this.job,
    required this.user,
    required this.adminService,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Text(job.title.isEmpty ? 'Untitled job' : job.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            _pill(job.status),
          ]),
          const SizedBox(height: 14),
          _detail('Category', _category(job.category)),
          _detail('Status', _label(job.status)),
          _detail('Address', job.address.isEmpty ? 'Address unavailable' : job.address),
          _detail('Schedule', _schedule(job)),
          _detail('Budget', 'PKR ${_format.format(job.budgetMin)} – ${_format.format(job.budgetMax)}'),
          _detail('Client', job.clientName.isEmpty ? 'Unknown client' : job.clientName),
          if (job.workerId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Worker'),
              subtitle: Text(job.workerName ?? 'Worker profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AdminAccountDetailScreen(
                  uid: job.workerId!,
                  worker: true,
                  user: user,
                  adminService: adminService,
                ),
              )),
            )
          else
            _detail('Worker', 'Unassigned'),
          if (job.status != 'completed' && job.status != 'cancelled') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('admin-cancel-job'),
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, color: AppTheme.dangerRed),
                label: const Text('Cancel job', style: TextStyle(color: AppTheme.dangerRed)),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  static Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
    ]),
  );

  static Widget _pill(String status) => StatusPill(
    label: _label(status),
    color: switch (status.toLowerCase()) {
      'open' || 'pending' => AppTheme.accentYellow,
      'completed' => AppTheme.successGreen,
      'cancelled' => AppTheme.dangerRed,
      _ => AppTheme.brandBlue,
    },
  );

  static String _label(String status) => status == 'inProgress'
      ? 'In progress'
      : status.isEmpty
          ? 'Unknown'
          : '${status[0].toUpperCase()}${status.substring(1)}';

  static String _category(String category) => category.isEmpty
      ? 'Other'
      : category.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}').replaceFirstMapped(
          RegExp(r'^[a-z]'),
          (match) => match[0]!.toUpperCase(),
        );

  static String _schedule(AdminJobRow row) {
    final date = row.preferredDate;
    if (date == null) return 'Not scheduled';
    final time = row.preferredTime;
    return '${DateFormat('EEE, d MMM yyyy', 'en').format(date)}${time == null ? '' : ' · ${DateFormat('HH:mm', 'en').format(time)}'}';
  }

  static final NumberFormat _format = NumberFormat('#,##0', 'en_PK');
}
