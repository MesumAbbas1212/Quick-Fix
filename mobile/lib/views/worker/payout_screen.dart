import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/payout_request.dart';
import 'package:quickfix/services/payout_service.dart';
class PayoutScreen extends StatefulWidget {
  final String workerId;
  final PayoutService? payoutService;
  const PayoutScreen({super.key, required this.workerId, this.payoutService});
  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}
class _PayoutScreenState extends State<PayoutScreen> {
  late final PayoutService _service = widget.payoutService ?? PayoutService();
  late Future<PayoutSnapshot> _future = _load();
  final _account = TextEditingController(), _amount = TextEditingController();
  String _method = 'jazzcash';
  String? _attemptId, _error;
  bool _busy = false, _initialized = false, _hidden = true;
  PayoutRequest? _confirmed;
  Future<PayoutSnapshot> _load() async => await _service.load(widget.workerId);
  void _retry() => setState(() { _future = _load(); });
  @override
  void dispose() { _account.dispose(); _amount.dispose(); super.dispose(); }
  String _money(int paisa) => 'PKR ${intl.NumberFormat('#,##0.00', 'en').format(paisa / 100)}';
  Future<void> _request(PayoutSnapshot snapshot) async {
    if (_busy) return;
    final paisa = PayoutService.parsePaisa(_amount.text);
    if (paisa == null || paisa <= 0 || paisa > snapshot.availablePaisa || !RegExp(r'^[A-Za-z0-9 +_-]{3,64}$').hasMatch(_account.text.trim())) {
      setState(() { _error = 'Use up to two decimal places, an amount within balance, and a demo account reference (3–64 characters).'; }); return;
    }
    final yes = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Record simulated withdrawal?'), content: Text('${_money(paisa)} will be reserved in the demo ledger. No real money is transferred.'),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not now')), TextButton(key: const Key('payout-confirm'), onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Record request'))]));
    if (yes != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      _attemptId ??= _service.newRequestId();
      final confirmed = await _service.request(uid: widget.workerId, requestId: _attemptId!, amountPaisa: paisa, method: _method, accountRef: _account.text.trim());
      if (mounted) setState(() { _confirmed = confirmed; _future = _load(); });
    } catch (_) { if (mounted) setState(() { _error = 'Withdrawal was not confirmed. Keep this request ID and refresh history before retrying; a pending request may already exist.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Simulated withdrawal', maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(tooltip: 'Refresh withdrawal balance/history', onPressed: _busy ? null : _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: FutureBuilder<PayoutSnapshot>(future: _future, builder: (context, snapshot) {
      final confirmed = _confirmed;
      if (snapshot.hasError && confirmed == null) return ErrorState(message: 'Could not load a server-confirmed withdrawal balance.', onRetry: _retry);
      if (!snapshot.hasData && confirmed == null) return const LoadingList();
      final data = snapshot.data;
      if (!_initialized && data != null) { _initialized = true; _method = PayoutService.methods.contains(data.method) ? data.method : 'jazzcash'; _account.text = data.accountRef; }
      return ListView(padding: const EdgeInsets.all(16), children: [
        const AppCard(child: Text('Simulation only — no bank, JazzCash or EasyPaisa transfer occurs. Use a DEMO account identifier, not real banking secrets. This is not a production wallet.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.brandBlue))), const SizedBox(height: 14),
        if (confirmed != null) ...[AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Request ${confirmed.status}: ${_money(confirmed.amountPaisa)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), Text('Method: ${confirmed.method} • Reference ${confirmed.id}'),
          const Text('Pending means an in-app record, not a promised payout time. Refresh to see operator status.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          TextButton(key: const Key('payout-new-request'), onPressed: _busy ? null : () => setState(() { _confirmed = null; _attemptId = null; _amount.clear(); _future = _load(); }), child: const Text('Start another request'))])), const SizedBox(height: 14)],
        if (snapshot.hasError) ErrorState(message: 'The request is recorded, but refreshed history is unavailable.', onRetry: _retry),
        if (data != null) ...[
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Available: ${_money(data.availablePaisa)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text('Paid receipts ${_money(data.receivedPaisa)} • reserved/paid out ${_money(data.reservedPaisa)}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const Text('Fee: PKR 0 in this simulation. Budgets, failed receipts and unpaid jobs are not balance.'),
            if (data.reservedPaisa > data.receivedPaisa) const Text('Recorded reservations exceed receipts. Ask the operator to review the demo data.'),
          ])),
          if (confirmed == null) ...[
            DropdownButtonFormField<String>(key: const Key('payout-method'), initialValue: _method, isExpanded: true, decoration: const InputDecoration(labelText: 'Method'),
              items: const [DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')), DropdownMenuItem(value: 'easypaisa', child: Text('EasyPaisa')), DropdownMenuItem(value: 'bank', child: Text('Bank'))], onChanged: _busy ? null : (value) => setState(() { _method = value ?? 'jazzcash'; })),
            const SizedBox(height: 12), TextField(key: const Key('payout-account'), controller: _account, enabled: !_busy, obscureText: _hidden, autocorrect: false, enableSuggestions: false, maxLength: 64,
              decoration: InputDecoration(labelText: _method == 'bank' ? 'Demo IBAN/account reference' : 'Demo mobile/account reference', suffixIcon: IconButton(tooltip: _hidden ? 'Show demo reference' : 'Hide demo reference', onPressed: _busy ? null : () => setState(() { _hidden = !_hidden; }), icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
            TextField(key: const Key('payout-amount'), controller: _amount, enabled: !_busy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (PKR)')),
            TextButton(key: const Key('payout-all'), onPressed: _busy || data.availablePaisa <= 0 ? null : () => setState(() { _amount.text = (data.availablePaisa / 100).toStringAsFixed(2); }), child: const Text('Withdraw all')),
            if (_error != null) Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed)),
            ElevatedButton(key: const Key('payout-request'), onPressed: _busy || data.availablePaisa <= 0 ? null : () => _request(data), child: Text(_busy ? 'Recording…' : 'Request simulated withdrawal')),
          ],
          const SizedBox(height: 18), const Text('Request history', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (data.history.isEmpty) EmptyState(icon: Icons.receipt_long_outlined, title: 'No withdrawal requests yet', message: 'Requests appear here after the record is acknowledged.', action: OutlinedButton(onPressed: _retry, child: const Text('Refresh history'))),
          for (final item in data.history) ListTile(title: Text('${_money(item.amountPaisa)} • ${item.status}'), subtitle: Text('${item.method} • ${item.createdAt == null ? 'Date pending' : intl.DateFormat('d MMM yyyy', 'en').format(item.createdAt!)}')),
        ],
      ]);
    })),
  ));
}
