import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/local_photo_viewer.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_content.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/profile_service.dart';
class PortfolioScreen extends StatefulWidget {
  final String workerId;
  final bool readOnly;
  final ProfileService? profileService;
  final LocalImageStore? imageStore;
  final ImagePicker? imagePicker;
  const PortfolioScreen({super.key, required this.workerId, this.readOnly = false, this.profileService, this.imageStore, this.imagePicker});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}
class _PortfolioScreenState extends State<PortfolioScreen> {
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late final LocalImageStore _images = widget.imageStore ?? const LocalImageStore();
  late Stream<List<PortfolioWork>> _stream = _watch();
  bool _busy = false;
  Stream<List<PortfolioWork>> _watch() { try { return _profiles.watchPortfolio(widget.workerId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); });
  void _message(String text) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); } }
  Future<void> _add() async {
    if (_busy || widget.readOnly) { return; } setState(() { _busy = true; });
    try {
      final photo = await (widget.imagePicker ?? ImagePicker()).pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80).timeout(const Duration(minutes: 2));
      if (photo == null || !mounted) { return; }
      var caption = ''; var category = JobCategory.other; final form = GlobalKey<FormState>();
      final metadata = await showDialog<(String, JobCategory)>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(title: const Text('Describe your work'),
        content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(key: const Key('portfolio-caption'), maxLength: 500, minLines: 1, maxLines: 4, textDirection: contentDirection(caption), decoration: const InputDecoration(labelText: 'Caption'), onChanged: (value) => update(() { caption = value; }), validator: (value) => value == null || value.trim().isEmpty ? 'Add a caption.' : null),
          DropdownButtonFormField<JobCategory>(initialValue: category, isExpanded: true, items: [for (final item in JobCategory.values) DropdownMenuItem(value: item, child: Text(jobCategoryLabel(item)))], onChanged: (value) => update(() { category = value ?? JobCategory.other; })),
        ]))), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')), TextButton(key: const Key('portfolio-metadata-save'), onPressed: () { if (form.currentState!.validate()) { Navigator.of(dialogContext).pop((caption.trim(), category)); } }, child: const Text('Add work'))],
      )));
      if (metadata == null) { return; }
      final paths = await _images.saveImages([photo]).timeout(const Duration(seconds: 8));
      await _profiles.addPortfolio(widget.workerId, path: paths.single, caption: metadata.$1, category: metadata.$2);
    } catch (_) { _message('Could not confirm the portfolio listing. A local copy may remain; retry or clear app data later.'); }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  Future<bool> _delete(PortfolioWork work) async {
    if (_busy || widget.readOnly) { return false; }
    final yes = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Remove this work listing?'), content: const Text('The listing is removed. Local cached copies remain until app-data/account cleanup; other devices are not wiped.'),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep')), TextButton(key: const Key('portfolio-delete-confirm'), onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remove'))]));
    if (yes != true || !mounted) { return false; } setState(() { _busy = true; });
    try { await _profiles.removePortfolio(widget.workerId, work.id); return true; } catch (_) { _message('Could not remove the listing. Please retry.'); return false; }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Portfolio'), actions: [IconButton(tooltip: 'Refresh portfolio', onPressed: _busy ? null : _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: StreamBuilder<List<PortfolioWork>>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) { return ErrorState(message: 'Could not load work examples.', onRetry: _retry); }
      if (!snapshot.hasData) { return const LoadingList(); }
      final works = snapshot.data!;
      if (works.isEmpty) { return SingleChildScrollView(child: EmptyState(icon: Icons.photo_library_outlined, title: widget.readOnly ? 'No work examples shared yet' : 'Show clients your work',
        message: 'Photos are device-local, not uploads. A reference may be unreadable on another device.', action: widget.readOnly ? OutlinedButton(onPressed: _retry, child: const Text('Refresh portfolio')) : ElevatedButton(key: const Key('portfolio-add'), onPressed: _busy ? null : _add, child: Text(_busy ? 'Adding…' : 'Add work')))); }
      return LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 500 && MediaQuery.textScalerOf(context).scale(14) < 21 ? 2 : 1;
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: (works.length / columns).ceil() + 1, itemBuilder: (context, index) {
          if (index == 0) { return Column(children: [const Text('Device-local photos are not remotely viewable uploads. Captions/categories remain visible even when files are missing.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            if (!widget.readOnly) TextButton.icon(key: const Key('portfolio-add'), onPressed: _busy ? null : _add, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_busy ? 'Adding…' : 'Add work')), const SizedBox(height: 14)]); }
          final start = (index - 1) * columns;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var column = 0; column < columns; column++) Expanded(child: start + column >= works.length ? const SizedBox() : Padding(padding: const EdgeInsetsDirectional.only(end: 8, bottom: 14), child: _card(works[start + column])))]);
        });
      });
    })),
  );
  Widget _card(PortfolioWork work) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    InkWell(key: Key('portfolio-photo-${work.id}'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocalPhotoViewer(imagePath: work.imagePath, caption: work.caption, imageStore: widget.imageStore, onDelete: widget.readOnly ? null : () => _delete(work)))), child: LocalPhotoThumb(path: work.imagePath, imageStore: widget.imageStore)),
    const SizedBox(height: 8), Text(work.caption, textDirection: contentDirection(work.caption), style: const TextStyle(fontSize: 13)), Text(jobCategoryLabel(work.category), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
    if (!widget.readOnly) IconButton(key: Key('portfolio-remove-${work.id}'), tooltip: 'Remove work listing', onPressed: _busy ? null : () => _delete(work), icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed)),
  ]));
}
