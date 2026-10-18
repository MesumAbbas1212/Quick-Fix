import 'package:quickfix/views/settings/legal_screen.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_verification.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/verification_service.dart';

class VerificationScreen extends StatefulWidget {
  final UserModel user;
  final VerificationService? verificationService;
  final LocalImageStore? imageStore;
  final ImagePicker? imagePicker;
  const VerificationScreen({super.key, required this.user, this.verificationService, this.imageStore, this.imagePicker});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}
class _VerificationScreenState extends State<VerificationScreen> {
  late final LocalImageStore _images = widget.imageStore ?? const LocalImageStore();
  late final VerificationService _service = widget.verificationService ?? VerificationService(imageStore: _images);
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();
  WorkerVerification _record = const WorkerVerification();
  final Map<String, String> _paths = {};
  final Map<String, Future<Uint8List?>> _previews = {};
  bool _loading = true;
  bool _loadFailed = false;
  bool _consent = false;
  bool _submitting = false;
  String? _capturing;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _loadFailed = false; _error = null; });
    try {
      final record = await _service.getVerification(widget.user.uid).timeout(const Duration(seconds: 11));
      if (!mounted) return;
      setState(() {
        _record = record ?? const WorkerVerification(); _loading = false; _consent = false;
        _paths.clear();
        if (_record.cnicFrontPath != null) _paths['front'] = _record.cnicFrontPath!;
        if (_record.cnicBackPath != null) _paths['back'] = _record.cnicBackPath!;
        if (_record.selfiePath != null) _paths['selfie'] = _record.selfiePath!;
      });
    } catch (_) { if (mounted) setState(() { _loading = false; _loadFailed = true; }); }
  }
  Future<void> _capture(String kind) async {
    if (_capturing != null || _submitting) return;
    setState(() { _capturing = kind; _error = null; });
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera,
        preferredCameraDevice: kind == 'selfie' ? CameraDevice.front : CameraDevice.rear,
        maxWidth: 1600, imageQuality: 80).timeout(const Duration(seconds: 60));
      if (picked == null) return;
      final path = await _images.saveVerificationImage(uid: widget.user.uid, kind: kind, picked: picked).timeout(const Duration(seconds: 8));
      if (mounted) setState(() { _paths[kind] = path; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not capture this photo. Check camera permission in device settings and try again.'; });
    } finally { if (mounted) setState(() { _capturing = null; }); }
  }
  Future<void> _submit() async {
    if (_submitting || !_consent || _paths.length != 3 || _capturing != null) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await _service.submit(uid: widget.user.uid, cnicFrontPath: _paths['front']!, cnicBackPath: _paths['back']!,
        selfiePath: _paths['selfie']!, consent: _consent).timeout(const Duration(seconds: 16));
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() { _error = error is VerificationException ? error.message :
        'Could not confirm submission. Refresh status before retrying; a timed-out request may still complete.'; });
    } finally { if (mounted) setState(() { _submitting = false; }); }
  }
  Future<Uint8List?> _preview(String path) => _previews.putIfAbsent(path, () async {
    try { return await _images.readVerificationImage(widget.user.uid, path).timeout(const Duration(seconds: 3)); }
    catch (_) { return null; }
  });
  Widget _photo(String kind, String label) {
    final path = _paths[kind];
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
      if (path != null) FutureBuilder<Uint8List?>(key: ValueKey(path), future: _preview(path), builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const SizedBox(height: 140, child: LoadingList(rows: 1));
        if (snapshot.data == null) return const Text('Photo not available on this device. Please recapture.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted));
        return Semantics(label: '$label stored on this device', child: Image.memory(snapshot.data!, height: 140, fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('Photo cannot be displayed. Please recapture.')));
      }),
      OutlinedButton.icon(key: Key('verification-$kind'), onPressed: _capturing != null || _submitting ? null : () => _capture(kind),
        icon: const Icon(Icons.camera_alt_outlined), label: Text(_capturing == kind ? 'Capturing…' : path == null ? 'Capture $label' : 'Retake $label')),
    ])));
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_submitting, child: Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Verification'), actions: [IconButton(key: const Key('verification-refresh'), tooltip: 'Refresh status',
      onPressed: _loading || _submitting || _capturing != null ? null : _load, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: _loading ? const LoadingList(rows: 3) : _loadFailed ? ErrorState(
      message: 'Could not load your verification. Check your connection and try again.', onRetry: _load) : ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(_record.status == VerificationStatus.verified ? Icons.verified_outlined : Icons.shield_outlined, color: AppTheme.brandBlue),
          const SizedBox(width: 8), Expanded(child: Text(_record.status.label, key: const Key('verification-status'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))]),
        const SizedBox(height: 8), Text(switch (_record.status) {
          VerificationStatus.notStarted => 'Capture all three photos and read the consent below to request a manual review.',
          VerificationStatus.pending => 'Your request is pending manual review. Remote admins cannot open device-local photos; arrange a separate approved secure or in-person check.',
          VerificationStatus.verified => 'An admin recorded a manual identity check. This is not an automated identity or background check.',
          VerificationStatus.rejected => 'Please address the reviewer’s note and resubmit when ready.',
        }, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        if (_record.note?.trim().isNotEmpty ?? false) ...[const SizedBox(height: 10), Text(_record.note!, textDirection: contentDirection(_record.note!),
          style: const TextStyle(fontSize: 13, color: AppTheme.textDark))],
      ])), const SizedBox(height: 14),
      const AppCard(child: Text('Privacy — demo verification\n\nPhotos stay in this device’s private app directory, not Firebase Storage. '
        'Only your account and admins can read submitted file references and review notes in Firestore. Other users see status and dates only. '
        'Remote admins cannot view these local photos. An admin must perform a separate approved secure or in-person check before marking Verified. '
        'Use test/demo images here, not real identity documents. Local copies remain until app-data/account cleanup; removing the app does not delete the Firestore references.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted))),
      TextButton(key: const Key('verification-privacy'), onPressed: _submitting ? null : () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LegalScreen(initialTab: 1))), child: const Text('Read full privacy practices')),
      if (_record.canSubmit) ...[
        const SizedBox(height: 16), _photo('front', 'CNIC front'), _photo('back', 'CNIC back'), _photo('selfie', 'Selfie'),
        CheckboxListTile(key: const Key('verification-consent'), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
          value: _consent, onChanged: _submitting ? null : (value) => setState(() { _consent = value ?? false; }),
          title: const Text('I consent to storing these device-local photos and submitting private file references for manual verification. I understand the demo limitations above.', style: TextStyle(fontSize: 13))),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
        ElevatedButton(key: const Key('verification-submit'), onPressed: !_consent || _paths.length != 3 || _submitting || _capturing != null ? null : _submit,
          child: Text(_submitting ? 'Submitting…' : _record.status == VerificationStatus.rejected ? 'Resubmit for verification' : 'Submit for verification')),
      ],
    ])),
  ));
}
