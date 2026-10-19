import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/local_photo_viewer.dart';
import 'package:quickfix/models/worker_content.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/profile_service.dart';
class CertificationsScreen extends StatefulWidget {
  final String workerId;
  final bool readOnly;
  final ProfileService? profileService;
  final LocalImageStore? imageStore;
  final ImagePicker? imagePicker;
  const CertificationsScreen({super.key, required this.workerId, this.readOnly = false, this.profileService, this.imageStore, this.imagePicker});
  @override
  State<CertificationsScreen> createState() => _CertificationsScreenState();
}
class _CertificationsScreenState extends State<CertificationsScreen> {
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late Stream<List<WorkerCertificate>> _stream = _watch();
  bool _busy = false;
  Stream<List<WorkerCertificate>> _watch() { try { return _profiles.watchCertificates(widget.workerId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); });
  Future<void> _add() async {
    if (_busy || widget.readOnly) return; setState(() { _busy = true; });
    try {
      var title = '', issuer = '', year = ''; var withPhoto = false; final form = GlobalKey<FormState>();
      final draft = await showDialog<(WorkerCertificate, bool)>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(title: const Text('Add certification'),
        content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(key: const Key('certificate-title'), maxLength: 120, textDirection: contentDirection(title), decoration: const InputDecoration(labelText: 'Title'), onChanged: (value) => update(() { title = value; }), validator: (value) => value == null || value.trim().isEmpty ? 'Add a title.' : null),
          TextFormField(key: const Key('certificate-issuer'), maxLength: 120, textDirection: contentDirection(issuer), decoration: const InputDecoration(labelText: 'Issuer'), onChanged: (value) => update(() { issuer = value; }), validator: (value) => value == null || value.trim().isEmpty ? 'Add an issuer.' : null),
          TextFormField(key: const Key('certificate-year'), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Year (1970–${DateTime.now().year})'), onChanged: (value) { year = value; }, validator: (value) { final number = int.tryParse(value ?? ''); return number == null || number < 1970 || number > DateTime.now().year ? 'Enter a valid issued year.' : null; }),
          CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Add optional device-local photo'), value: withPhoto, onChanged: (value) => update(() { withPhoto = value ?? false; })),
        ]))), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')), TextButton(key: const Key('certificate-form-save'), onPressed: () { if (form.currentState!.validate()) Navigator.of(dialogContext).pop((WorkerCertificate(id: '', title: title, issuer: issuer, year: int.parse(year)), withPhoto)); }, child: const Text('Save'))],
      )));
      if (draft == null) return;
      var path = '';
      if (draft.$2) {
        final image = await (widget.imagePicker ?? ImagePicker()).pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80).timeout(const Duration(minutes: 2));
        if (image == null) return;
        path = (await (widget.imageStore ?? const LocalImageStore()).saveImages([image]).timeout(const Duration(seconds: 8))).single;
      }
      await _profiles.addCertificate(widget.workerId, WorkerCertificate(id: '', title: draft.$1.title, issuer: draft.$1.issuer, year: draft.$1.year, imagePath: path));
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not confirm the certificate listing. Retry; local cached copies may remain.'))); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  Future<void> _remove(WorkerCertificate certificate) async {
    if (_busy || widget.readOnly) return;
    final yes = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Remove certification?'), content: const Text('Removes this self-declared listing, not copies on other devices.'), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep')),
      TextButton(key: const Key('certificate-delete-confirm'), onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remove'))]));
    if (yes != true || !mounted) return; setState(() { _busy = true; });
    try { await _profiles.removeCertificate(widget.workerId, certificate.id); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove the certification. Please retry.'))); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Certifications')),
    body: SafeArea(child: StreamBuilder<List<WorkerCertificate>>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'Could not load certifications.', onRetry: _retry);
      if (!snapshot.hasData) return const LoadingList();
      final items = snapshot.data!;
      if (items.isEmpty) return EmptyState(icon: Icons.school_outlined, title: 'No certifications listed', message: 'Credentials are self-declared, not verified licences. Photos stay on the capturing device.',
        action: widget.readOnly ? OutlinedButton(onPressed: _retry, child: const Text('Refresh')) : ElevatedButton(key: const Key('certificate-add'), onPressed: _busy ? null : _add, child: const Text('Add certification')));
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Self-declared credentials — not QuickFix verification or a licence guarantee. Photos are device-local references, not remote uploads. Do not attach sensitive identity documents.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        if (!widget.readOnly) TextButton.icon(key: const Key('certificate-add'), onPressed: _busy ? null : _add, icon: const Icon(Icons.add), label: Text(_busy ? 'Saving…' : 'Add certification')),
        for (final item in items) Padding(padding: const EdgeInsets.only(top: 14), child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, textDirection: contentDirection(item.title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(item.issuer, textDirection: contentDirection(item.issuer), style: const TextStyle(fontSize: 13)), Text(item.year >= 1970 ? '${item.year} • Self-declared' : 'Year not provided • Self-declared', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          if (item.imagePath.isNotEmpty) InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocalPhotoViewer(imagePath: item.imagePath, caption: '${item.title} — ${item.issuer}', imageStore: widget.imageStore))), child: LocalPhotoThumb(path: item.imagePath, imageStore: widget.imageStore)),
          if (!widget.readOnly) IconButton(key: Key('certificate-remove-${item.id}'), tooltip: 'Remove certification', onPressed: _busy ? null : () => _remove(item), icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed)),
        ]))),
      ]);
    })),
  );
}
