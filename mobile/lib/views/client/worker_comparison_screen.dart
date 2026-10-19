import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/worker_comparison_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
class WorkerComparisonScreen extends StatefulWidget {
  final String myId;
  final List<WorkerProfile> workers;
  final GeoPoint? origin;
  final JobService? jobService;
  final ChatService? chatService;
  final WorkerComparisonService? comparisonService;
  const WorkerComparisonScreen({super.key, required this.myId, required this.workers, this.origin, this.jobService, this.chatService, this.comparisonService});
  @override
  State<WorkerComparisonScreen> createState() => _WorkerComparisonScreenState();
}
class _WorkerComparisonScreenState extends State<WorkerComparisonScreen> {
  late final WorkerComparisonService _service = widget.comparisonService ?? WorkerComparisonService(jobService: widget.jobService);
  final _counts = <String, Future<int>>{};
  Future<int> _annual(String uid) => _counts.putIfAbsent(uid, () => _service.annualCount(uid));
  Widget _annualCell(WorkerProfile worker, {bool rank = false}) => FutureBuilder<int>(future: _annual(worker.uid), builder: (context, snapshot) {
    if (snapshot.hasError) return const Tooltip(message: 'Annual work history unavailable — retry from the toolbar', child: Text('—'));
    if (!snapshot.hasData) return const Text('Loading history…', style: TextStyle(fontSize: 12, color: AppTheme.textMuted));
    return rank ? RankBadge(rank: WorkerRank.forCompletedInYear(snapshot.data!), emblemSize: 32) : Text('${snapshot.data!}', style: const TextStyle(fontSize: 14));
  });
  String _price(WorkerProfile worker) {
    if (!worker.minBudget.isFinite || !worker.maxBudget.isFinite || worker.minBudget < 0 || worker.maxBudget <= 0 || worker.maxBudget < worker.minBudget) return '—';
    final money = intl.NumberFormat('#,##0.##', 'en'); return 'PKR ${money.format(worker.minBudget)}–${money.format(worker.maxBudget)}';
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Compare workers'), actions: [IconButton(key: const Key('comparison-retry'), tooltip: 'Retry annual-history cells', onPressed: () => setState(() { _counts.clear(); }), icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: (!WorkerComparisonService.validSelection(widget.workers) || widget.workers.any((worker) => worker.uid == widget.myId)) ? EmptyState(icon: Icons.compare_arrows_outlined, title: 'Choose 2–3 different workers', message: 'Return to Workers and select a shortlist.', action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to workers'))) : LayoutBuilder(builder: (context, constraints) {
      final column = math.max(220.0, MediaQuery.textScalerOf(context).scale(14) * 12).toDouble(); const label = 120.0;
      Widget row(String title, Widget Function(WorkerProfile) value) => IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: label, child: _cell(Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), header: true)),
        for (final worker in widget.workers) SizedBox(width: column, child: _cell(value(worker))),
      ]));
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: label + column * widget.workers.length, height: constraints.maxHeight, child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(width: label, child: Padding(padding: EdgeInsets.all(14), child: Text('Shortlist snapshot\nSwipe horizontally', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)))),
          for (final worker in widget.workers) SizedBox(width: column, child: _cell(Column(children: [UserAvatar(fullName: worker.fullName, avatarUrl: worker.avatarUrl, size: 56), const SizedBox(height: 8),
            ConstrainedBox(constraints: BoxConstraints(maxHeight: math.min(100.0, constraints.maxHeight * .18).toDouble()), child: SingleChildScrollView(child: Text(worker.fullName, textDirection: contentDirection(worker.fullName), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))))]))),
        ]),
        Expanded(child: SingleChildScrollView(child: Column(children: [
          row('Rank (trailing year)', (worker) => _annualCell(worker, rank: true)), row('Jobs in trailing year', (worker) => _annualCell(worker)),
          row('Rating', (worker) => Text(worker.reviews > 0 && worker.rating.isFinite && worker.rating >= 0 && worker.rating <= 5 ? worker.rating.toStringAsFixed(1) : '—')),
          row('Distance', (worker) { final distance = _service.distanceKm(worker, widget.origin); return Text(distance == null ? '—' : '${distance.toStringAsFixed(1)} km'); }),
          row('Posted price range', (worker) => Text(_price(worker))), row('Spoken languages', (worker) => Text(worker.languages.isEmpty ? '—' : worker.languages.join(', '), textDirection: contentDirection(worker.languages.join(', ')))),
          row('Availability', (worker) => Text(worker.isAvailable ? 'Available' : 'Unavailable')),
          const Padding(padding: EdgeInsets.all(14), child: Text('Profile fields are the selected snapshots; refresh annual history separately. Posted ranges are not fixed quotes. Unknown cells stay —, not invented zeroes.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
        ]))),
        Row(children: [const SizedBox(width: label, child: Padding(padding: EdgeInsets.all(14), child: Text('Contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
          for (final worker in widget.workers) SizedBox(width: column, child: Padding(padding: const EdgeInsets.all(10), child: ElevatedButton(key: Key('comparison-chat-${worker.uid}'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(myId: widget.myId, peerId: worker.uid, peerName: worker.fullName, chatService: widget.chatService))), child: const Text('Chat')))),
        ]),
      ])));
    })),
  );
  Widget _cell(Widget child, {bool header = false}) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: header ? AppTheme.bgLight : AppTheme.surfaceWhite,
    border: const Border(bottom: BorderSide(color: AppTheme.borderGray), right: BorderSide(color: AppTheme.borderGray))), child: child);
}
