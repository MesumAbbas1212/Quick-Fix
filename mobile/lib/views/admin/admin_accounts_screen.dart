import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/core/widgets/status_pill.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_account_detail_screen.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class AdminAccountsScreen extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  final AdminService? adminService;
  final bool startWithWorkers;
  const AdminAccountsScreen({super.key, required this.user, this.authService, this.adminService, this.startWithWorkers = false});
  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  late final AdminService _service = widget.adminService ?? AdminService();
  late bool _workers = widget.startWithWorkers;
  final _search = TextEditingController();
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), child: SegmentedButton<bool>(
      key: const Key('admin-account-segment'), segments: const [ButtonSegment(value: false, label: Text('Users')), ButtonSegment(value: true, label: Text('Workers'))],
      selected: {_workers}, onSelectionChanged: (value) => setState(() => _workers = value.first),
    )),
    Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 10), child: TextField(key: const Key('admin-account-search'), controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name or email'))),
    Expanded(child: StreamBuilder<List<AdminAccountRow>>(
      key: ValueKey('admin-accounts-$_workers'),
      stream: _workers ? _service.watchWorkers(limit: 50) : _service.watchUsers(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.hasError) return AdminError(onRetry: () => setState(() {}));
        if (snapshot.connectionState == ConnectionState.waiting) return const AdminLoading(rows: 6);
        final page = snapshot.data ?? const <AdminAccountRow>[];
        final all = _workers ? page : page.where((row) => row.role == 'user').toList(growable: false);
        if (all.isEmpty) return AdminEmpty(title: 'No ${_workers ? 'workers' : 'users'} found', message: 'Accounts will appear here when they have been created.');
        final query = _search.text.trim().toLowerCase();
        final matches = all.where((row) => row.name.toLowerCase().contains(query) || row.email.toLowerCase().contains(query) || row.uid.toLowerCase().contains(query)).toList();
        if (matches.isEmpty) return const AdminEmpty(title: 'No search matches', message: 'Try a different name, email or account ID.');
        return ListView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: matches.length, itemBuilder: (context, index) => _row(context, matches[index]));
      },
    )),
  ]);

  Widget _row(BuildContext context, AdminAccountRow account) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AdminCard(child: ListTile(
    key: Key('admin-account-${account.uid}'), contentPadding: EdgeInsets.zero,
    leading: UserAvatar(fullName: account.name, avatarUrl: account.avatarUrl, size: 46),
    title: Text(account.name.isEmpty ? account.email : account.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(account.email, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4), Wrap(spacing: 6, runSpacing: 4, children: [
        StatusPill(label: account.role, color: AppTheme.brandBlue),
        if (account.blocked) const StatusPill(label: 'Blocked', color: AppTheme.textMuted),
        if (_workers) Text('★ ${account.rating.toStringAsFixed(1)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]),
      if (_workers && account.completedInYear != null) Padding(padding: const EdgeInsets.only(top: 5), child: RankBadge(rank: WorkerRank.forCompletedInYear(account.completedInYear!), completedInYear: account.completedInYear!, fontSize: 10, emblemSize: 18)),
    ]),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminAccountDetailScreen(uid: account.uid, worker: _workers, user: widget.user, adminService: _service))),
  )));
}
