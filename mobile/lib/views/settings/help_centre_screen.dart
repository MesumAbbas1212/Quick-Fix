import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/services/support_service.dart';

const helpFaqs = <String, String>{
  'How do I post a job?': 'Choose a category, describe the work, add photos, budget and schedule, then verify the job pin. Choose a saved address, enter a pin manually or explicitly allow one GPS fix. There is no background tracking.',
  'How are workers selected?': 'Workers apply to open jobs. The owning client reviews applicants and chooses one; browsing a job does not let a worker self-assign it.',
  'Are payments and withdrawals real?': 'No. The prototype records simulated receipts and withdrawal requests only. No card is charged and no bank/JazzCash/EasyPaisa funds move. Verify any real-world agreement separately.',
  'Can I change or cancel a job?': 'The client can change the schedule or cancel assigned/in-progress work after confirmation. A cancelled job stays cancelled; it does not automatically reopen on the board. Completed records are read-only except post-job review/payment/report flows.',
  'How do reviews and languages work?': 'Reviews save before optional machine translation. Choose Review language in Settings from the available backend catalog. This controls review translation, not English navigation. Originals remain available; translation can fail or be inaccurate. Check My reviews before retrying an uncertain submit.',
  'What determines a worker rank?': 'Completed-work volume in a rolling 365-day window, not ratings, determines the rank. Open Rank progress to see the current thresholds and proper rank emblems.',
  'Why can’t I see a photo on another device?': 'Images are stored in the capturing device’s app directory. File references are not uploads. Portfolio, certificate and demo-verification images may therefore be unavailable elsewhere.',
  'How can I delete my account?': 'Settings → Delete account requires typed confirmation and password reauthentication. Active assigned work blocks cleanup. Failed cleanup can be partial: resume it after re-entering your password or at next sign-in. Read Privacy for retained/de-identified records and cache limitations.',
  'How do I report a problem?': 'Use Report on the job or worker/client profile for account-related abuse. A completed-job dispute records an issue for manual review. No automatic refund, live support desk or guaranteed response time is provided.',
};
class HelpCentreScreen extends StatefulWidget {
  final SupportService? supportService;
  const HelpCentreScreen({super.key, this.supportService});
  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}
class _HelpCentreScreenState extends State<HelpCentreScreen> {
  late final SupportService _support = widget.supportService ?? SupportService();
  final _search = TextEditingController();
  String _query = '';
  bool _busy = false;
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _contact() async {
    if (_busy) return; setState(() { _busy = true; });
    try {
      if (!await _support.contact()) throw StateError('No mail handler');
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open an email app. Copy the configured address below and contact it manually.'))); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  Future<void> _copy() async {
    try { await _support.copyContact(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support email copied'))); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not copy the contact. Select the email text to copy it manually.'))); }
  }
  @override
  Widget build(BuildContext context) {
    final entries = helpFaqs.entries.where((entry) => '${entry.key} ${entry.value}'.toLowerCase().contains(_query.trim().toLowerCase())).toList();
    return Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Help centre')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(key: const Key('help-search'), controller: _search, textDirection: contentDirection(_query), onChanged: (value) => setState(() { _query = value; }),
          decoration: const InputDecoration(labelText: 'Search help', prefixIcon: Icon(Icons.search))), const SizedBox(height: 16),
        if (entries.isEmpty) EmptyState(icon: Icons.search_off_outlined, title: 'No matching help articles', message: 'Try a broader term or show all topics.',
          action: OutlinedButton(key: const Key('help-clear-search'), onPressed: () => setState(() { _search.clear(); _query = ''; }), child: const Text('Show all topics'))),
        for (final entry in entries) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(padding: 0, child: ExpansionTile(key: ValueKey(entry.key),
          title: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), childrenPadding: const EdgeInsets.all(14),
          children: [Text(entry.value, style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted))]))),
        const SizedBox(height: 12), AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(key: const Key('help-contact-support'), contentPadding: EdgeInsets.zero, leading: const Icon(Icons.support_agent_outlined, color: AppTheme.brandBlue),
            title: Text(_support.isConfigured ? 'Contact support' : 'Support email not configured'),
            subtitle: Text(_support.isConfigured ? 'Opens your email app; do not send sensitive documents.' : 'Use the channel through which you received this demo. No support address has been invented.'),
            onTap: _support.isConfigured && !_busy ? _contact : null),
          if (_support.isConfigured) Row(children: [Expanded(child: SelectableText(_support.email, textDirection: TextDirection.ltr)),
            IconButton(key: const Key('help-copy-contact'), tooltip: 'Copy support email', onPressed: _busy ? null : _copy, icon: const Icon(Icons.copy_outlined))]),
        ])),
      ])),
    );
  }
}
