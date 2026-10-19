import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/location_selection.dart';
import 'package:quickfix/models/quote_inquiry.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/quote_service.dart';
import 'package:quickfix/views/client/location_picker_screen.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
class QuoteRequestScreen extends StatefulWidget {
  final UserModel user;
  final String? requestId;
  final QuoteService? quoteService;
  final ProfileService? profileService;
  final JobService? jobService;
  final LocationService? locationService;
  final LocalImageStore? imageStore;
  final ImagePicker? imagePicker;
  final UrlLauncher? urlLauncher;
  const QuoteRequestScreen({super.key, required this.user, this.requestId, this.quoteService, this.profileService, this.jobService, this.locationService, this.imageStore, this.imagePicker, this.urlLauncher});
  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}
class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  late final QuoteService _quotes = widget.quoteService ?? QuoteService(profileService: widget.profileService, jobService: widget.jobService);
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late Future<bool> _enabled = _quotes.isEnabled();
  late Stream<QuoteInquiry?> _request = _watchRequest();
  late Stream<List<QuoteInquiry>> _list = _watchList();
  Stream<List<WorkerQuote>>? _replies;
  String? _repliesKey, _attemptId, _error;
  final _description = TextEditingController(), _amount = TextEditingController(), _message = TextEditingController();
  final _workerNames = <String, Future<WorkerProfile?>>{};
  final _images = <String>[];
  JobCategory _category = JobCategory.other;
  LocationSelection? _location;
  double _radius = 10;
  Future<List<WorkerProfile>>? _candidates;
  bool _busy = false, _showOwned = false;
  Stream<QuoteInquiry?> _watchRequest() { try { return widget.requestId == null ? const Stream.empty() : _quotes.watchRequest(widget.requestId!); } catch (error, stack) { return Stream.error(error, stack); } }
  Stream<List<QuoteInquiry>> _watchList() { try { return widget.user.role == UserRole.worker ? _quotes.watchInvites(widget.user.uid) : _quotes.watchOwned(widget.user.uid); } catch (error, stack) { return Stream.error(error, stack); } }
  @override
  void dispose() { _description.dispose(); _amount.dispose(); _message.dispose(); super.dispose(); }
  void _retry() => setState(() { _enabled = _quotes.isEnabled(); _request = _watchRequest(); _list = _watchList(); _replies = null; _repliesKey = null; });
  void _lookup() { final pin = _location; if (pin != null) _candidates = _quotes.candidates(clientId: widget.user.uid, category: _category, location: pin.location, radiusKm: _radius); }
  Future<void> _pin() async {
    final pin = await Navigator.of(context).push<LocationSelection>(MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: _location?.location, initialAddress: _location?.address ?? '', locationService: widget.locationService)));
    if (pin != null && mounted) setState(() { _location = pin; _lookup(); });
  }
  Future<void> _photos() async {
    if (_busy) return; setState(() { _busy = true; });
    try {
      final picked = await (widget.imagePicker ?? ImagePicker()).pickMultiImage(maxWidth: 1600, imageQuality: 80).timeout(const Duration(minutes: 2));
      if (picked.isNotEmpty) { final paths = await (widget.imageStore ?? const LocalImageStore()).saveImages(picked.take(5 - _images.length).toList()).timeout(const Duration(seconds: 8)); if (mounted) setState(() { _images.addAll(paths); }); }
    } catch (_) { if (mounted) setState(() { _error = 'Could not copy local photos. Retry; nothing was uploaded.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  Future<void> _send(List<WorkerProfile> recipients) async {
    if (_busy || _location == null) return;
    if (_description.text.trim().length < 20 || recipients.isEmpty) { setState(() { _error = 'Write at least 20 characters and find available workers in range.'; }); return; }
    setState(() { _busy = true; _error = null; });
    try {
      _attemptId ??= _quotes.newInquiryId();
      final id = await _quotes.create(clientId: widget.user.uid, category: _category, description: _description.text.trim(), images: List.of(_images), location: _location!, radiusKm: _radius,
        expectedRecipients: recipients.map((worker) => worker.uid).toList(), requestId: _attemptId);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => QuoteRequestScreen(user: widget.user, requestId: id, quoteService: _quotes, profileService: widget.profileService, jobService: widget.jobService)));
    } catch (_) { if (mounted) setState(() { _error = 'Request was not confirmed, or recipients changed. Refresh the count before retrying; the same request ID is reused.'; _lookup(); }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  Future<void> _reply(QuoteInquiry inquiry) async {
    if (_busy) return;
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0 || amount > 1000000000 || ((amount * 100).round() - amount * 100).abs() > .0001 || _message.text.trim().length < 5) { setState(() { _error = 'Enter a positive price (two decimal places) and a message of at least five characters.'; }); return; }
    setState(() { _busy = true; _error = null; });
    try { await _quotes.reply(requestId: inquiry.id, workerId: widget.user.uid, amount: amount, message: _message.text.trim()); }
    catch (_) { if (mounted) setState(() { _error = 'Quote reply was not confirmed. Refresh before retrying; one reply per worker is recorded.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  Future<void> _book(QuoteInquiry inquiry, WorkerQuote quote) async {
    if (_busy) return;
    var title = 'Quoted ${jobCategoryLabel(inquiry.category)}'; var date = DateTime.now().add(const Duration(days: 1)); TimeOfDay? time; final form = GlobalKey<FormState>();
    final selection = await showDialog<(String, DateTime, TimeOfDay?)>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(title: const Text('Confirm quoted booking'),
      content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('PKR ${quote.amount.toStringAsFixed(2)} • confirm timing with the worker in Chat. No payment is taken here.'),
        TextFormField(initialValue: title, maxLength: 120, textDirection: contentDirection(title), decoration: const InputDecoration(labelText: 'Job title'), onChanged: (value) => update(() { title = value; }), validator: (value) => value == null || value.trim().isEmpty ? 'Add a title.' : null),
        TextButton(key: const Key('quote-book-date'), onPressed: () async { final now = DateTime.now(); final first = DateTime(now.year, now.month, now.day); final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: first, lastDate: first.add(const Duration(days: 365))); if (picked != null && dialogContext.mounted) update(() { date = picked; }); }, child: Text('Date: ${intl.DateFormat('d MMM yyyy', 'en').format(date)}')),
        TextButton(onPressed: () async { final picked = await showTimePicker(context: dialogContext, initialTime: time ?? const TimeOfDay(hour: 9, minute: 0)); if (picked != null && dialogContext.mounted) update(() { time = picked; }); }, child: Text(time == null ? 'Choose time (optional)' : 'Time: ${time!.format(dialogContext)}')),
      ]))), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Not now')), TextButton(key: const Key('quote-book-confirm'), onPressed: () { if (form.currentState!.validate()) Navigator.of(dialogContext).pop((title.trim(), date, time)); }, child: const Text('Book this price'))],
    )));
    if (selection == null || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final jobId = await _quotes.accept(requestId: inquiry.id, quoteId: quote.id, clientId: widget.user.uid, title: selection.$1, date: selection.$2,
        time: selection.$3 == null ? null : DateTime(2000, 1, 1, selection.$3!.hour, selection.$3!.minute));
      if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobTrackingScreen(jobId: jobId, myId: widget.user.uid, jobService: widget.jobService, reviewerLanguage: widget.user.preferredLanguage)));
    } catch (_) { if (mounted) setState(() { _error = 'Booking was not confirmed. Refresh this request before retrying; another quote or schedule may have been selected.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  Future<void> _area(GeoPoint point) async {
    try { if (!await (widget.urlLauncher ?? const MapLauncher()).openLocation(point.latitude, point.longitude).timeout(const Duration(seconds: 8))) throw StateError('No maps'); }
    catch (_) { if (mounted) setState(() { _error = 'Could not open the approximate area in Maps. Retry or check your map app.'; }); }
  }
  Future<WorkerProfile?> _worker(String uid) async => await _profiles.getWorkerProfile(uid).timeout(const Duration(seconds: 8));
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Quotes first'), actions: [IconButton(tooltip: 'Refresh quote request', onPressed: _busy ? null : _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: FutureBuilder<bool>(future: _enabled, builder: (context, flag) {
      if (flag.connectionState == ConnectionState.waiting) return const LoadingList();
      if (flag.hasError) return ErrorState(message: 'Could not check quote feature availability.', onRetry: _retry);
      if (flag.data != true) return EmptyState(icon: Icons.lock_outline, title: 'Quote requests are not enabled', message: 'The operator must validate A1–A4 and enable the protected feature flag first. No invitations or bookings were sent.', action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back')));
      if (widget.requestId != null) return _detail();
      if (widget.user.role == UserRole.worker || _showOwned) return _inbox();
      return _form();
    })),
  ));
  Widget _inbox() => StreamBuilder<List<QuoteInquiry>>(stream: _list, builder: (context, snapshot) {
    if (snapshot.hasError) return ErrorState(message: 'Could not load quote requests.', onRetry: _retry);
    if (!snapshot.hasData) return const LoadingList();
    if (snapshot.data!.isEmpty) return EmptyState(icon: Icons.request_quote_outlined, title: 'No quote requests here yet', message: widget.user.role == UserRole.worker ? 'Invitations from clients appear here.' : 'Create a request to compare available workers.', action: OutlinedButton(onPressed: widget.user.role == UserRole.worker ? _retry : () => setState(() { _showOwned = false; }), child: Text(widget.user.role == UserRole.worker ? 'Refresh invites' : 'Create request')));
    return ListView(padding: const EdgeInsets.all(14), children: [if (widget.user.role != UserRole.worker) TextButton(onPressed: () => setState(() { _showOwned = false; }), child: const Text('Create another request')),
      const Text('Latest 50 requests'), for (final inquiry in snapshot.data!) ListTile(title: Text(jobCategoryLabel(inquiry.category)), subtitle: Text(inquiry.status), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuoteRequestScreen(user: widget.user, requestId: inquiry.id, quoteService: _quotes, profileService: widget.profileService, jobService: widget.jobService))))]);
  });
  Widget _form() => ListView(padding: const EdgeInsets.all(16), children: [
    TextButton(key: const Key('quote-my-requests'), onPressed: () => setState(() { _showOwned = true; }), child: const Text('My quote requests')),
    const Text('Work description and an approximate area pin are visible to signed-in users. Keep exact addresses/contact secrets out of the description. Photos stay device-local.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
    TextField(key: const Key('quote-description'), controller: _description, enabled: !_busy, minLines: 3, maxLines: 8, maxLength: 2000, textDirection: contentDirection(_description.text), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Describe the work')),
    DropdownButtonFormField<JobCategory>(key: const Key('quote-category'), initialValue: _category, isExpanded: true, items: [for (final category in JobCategory.values) DropdownMenuItem(value: category, child: Text(jobCategoryLabel(category)))], onChanged: _busy ? null : (value) => setState(() { _category = value ?? JobCategory.other; _lookup(); })),
    OutlinedButton.icon(key: const Key('quote-location'), onPressed: _busy ? null : _pin, icon: const Icon(Icons.location_on_outlined), label: Text(_location == null ? 'Choose private exact pin/address' : 'Pin selected — edit')),
    Text('Radius: ${_radius.round()} km'), Slider(value: _radius, min: 1, max: 100, divisions: 99, onChanged: _busy ? null : (value) => setState(() { _radius = value; _candidates = null; }), onChangeEnd: _busy ? null : (_) => setState(_lookup)),
    OutlinedButton.icon(key: const Key('quote-photos'), onPressed: _busy || _images.length >= 5 ? null : _photos, icon: const Icon(Icons.photo_library_outlined), label: Text('Local photos (${_images.length}/5)')),
    const Text('Up to 10 nearest available workers from the existing ≤500-worker pool are invited; this is not a country-wide exhaustive match.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
    if (_candidates == null) TextButton(onPressed: _location == null || _busy ? null : () => setState(_lookup), child: const Text('Refresh recipient count')),
    if (_candidates != null) FutureBuilder<List<WorkerProfile>>(future: _candidates, builder: (context, recipients) {
      if (recipients.hasError) return ErrorState(message: 'Could not count available workers.', onRetry: () => setState(_lookup));
      if (!recipients.hasData) return const LoadingList(rows: 1);
      if (recipients.data!.isEmpty) return EmptyState(icon: Icons.people_outline, title: 'No available workers in range', message: 'Try a larger radius, another category or a different pin.', action: OutlinedButton(onPressed: _busy ? null : () => setState(() { _radius = 100; _lookup(); }), child: const Text('Widen to 100 km')));
      return ElevatedButton(key: const Key('quote-send'), onPressed: _busy ? null : () => _send(recipients.data!), child: Text(_busy ? 'Sending…' : 'Send to ${recipients.data!.length} workers'));
    }), if (_error != null) Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed)),
  ]);
  Widget _detail() => StreamBuilder<QuoteInquiry?>(stream: _request, builder: (context, snapshot) {
    if (snapshot.hasError) return ErrorState(message: 'Could not load this quote request.', onRetry: _retry);
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const LoadingList();
    final inquiry = snapshot.data;
    if (inquiry == null) return EmptyState(icon: Icons.request_quote_outlined, title: 'Request unavailable', message: 'It may have been removed during cleanup.', action: OutlinedButton(onPressed: _retry, child: const Text('Refresh')));
    final owner = inquiry.clientId == widget.user.uid;
    if (!owner && !inquiry.recipientIds.contains(widget.user.uid)) return const ErrorState(message: 'You were not invited to reply to this request.');
    final key = '${inquiry.id}:$owner'; if (_replies == null || _repliesKey != key) { _repliesKey = key; _replies = _quotes.watchQuotes(inquiry.id, widget.user.uid, owner: owner); }
    return StreamBuilder<List<WorkerQuote>>(stream: _replies, builder: (context, replies) {
      if (replies.hasError) return ErrorState(message: 'Could not load quote replies.', onRetry: _retry);
      if (!replies.hasData) return const LoadingList();
      return ListView(padding: const EdgeInsets.all(16), children: [AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${jobCategoryLabel(inquiry.category)} • ${inquiry.status}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
        Text(inquiry.description, textDirection: contentDirection(inquiry.description)), const SizedBox(height: 8), const Text('Area pin is approximate before booking. Local photo references are not remotely viewable uploads. A price is not a workmanship guarantee.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        if (inquiry.approximateLocation != null) TextButton.icon(onPressed: _busy ? null : () => _area(inquiry.approximateLocation!), icon: const Icon(Icons.map_outlined), label: Text('Approximate area: ${inquiry.approximateLocation!.latitude.toStringAsFixed(2)}, ${inquiry.approximateLocation!.longitude.toStringAsFixed(2)}')),
        if (inquiry.jobId != null && (owner || inquiry.acceptedWorkerId == widget.user.uid)) TextButton(key: const Key('quote-open-booking'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobTrackingScreen(jobId: inquiry.jobId!, myId: widget.user.uid, jobService: widget.jobService))), child: const Text('Open booked job')),
      ])), const SizedBox(height: 14),
        if (replies.data!.isEmpty && owner) EmptyState(icon: Icons.hourglass_empty, title: 'Waiting for worker replies', message: 'Invitations are in-app only; no response time is guaranteed.', action: OutlinedButton(onPressed: _retry, child: const Text('Refresh replies'))),
        for (final quote in replies.data!) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FutureBuilder<WorkerProfile?>(future: _workerNames.putIfAbsent(quote.workerId, () => _worker(quote.workerId)), builder: (context, worker) => Text(worker.hasError ? 'Worker name unavailable' : worker.connectionState == ConnectionState.waiting ? 'Loading worker…' : worker.data?.fullName ?? 'Former worker', textDirection: contentDirection(worker.data?.fullName ?? ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Text('PKR ${intl.NumberFormat('#,##0.00', 'en').format(quote.amount)} • ${inquiry.status == 'accepted' && inquiry.acceptedQuoteId != quote.id ? 'Not selected' : quote.status}'),
          Text(quote.message, textDirection: contentDirection(quote.message)), if (owner && inquiry.status == 'open' && quote.status == 'pending') ElevatedButton(key: Key('quote-accept-${quote.id}'), onPressed: _busy ? null : () => _book(inquiry, quote), child: const Text('Accept & choose schedule')),
        ])),
        if (!owner && inquiry.status == 'open' && replies.data!.isEmpty) ...[TextField(key: const Key('quote-reply-amount'), controller: _amount, enabled: !_busy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Your price (PKR)')),
          TextField(key: const Key('quote-reply-message'), controller: _message, enabled: !_busy, minLines: 2, maxLines: 5, maxLength: 1000, textDirection: contentDirection(_message.text), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Message / scope')),
          ElevatedButton(key: const Key('quote-reply-submit'), onPressed: _busy ? null : () => _reply(inquiry), child: Text(_busy ? 'Sending…' : 'Send quote'))],
        if (_error != null) Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed)),
      ]);
    });
  });
}
