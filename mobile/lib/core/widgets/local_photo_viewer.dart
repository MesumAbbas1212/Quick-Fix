import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/services/local_image_store.dart';
class LocalPhotoViewer extends StatefulWidget {
  final String imagePath, caption;
  final LocalImageStore? imageStore;
  final Future<bool> Function()? onDelete;
  const LocalPhotoViewer({super.key, required this.imagePath, required this.caption, this.imageStore, this.onDelete});
  @override
  State<LocalPhotoViewer> createState() => _LocalPhotoViewerState();
}
class _LocalPhotoViewerState extends State<LocalPhotoViewer> {
  late final LocalImageStore _images = widget.imageStore ?? const LocalImageStore();
  late Future<Uint8List?> _future = _load();
  bool _removing = false;
  Future<void> _remove() async {
    if (_removing || widget.onDelete == null) return; setState(() { _removing = true; });
    try { final removed = await widget.onDelete!(); if (removed && mounted) Navigator.of(context).pop(); }
    finally { if (mounted) setState(() { _removing = false; }); }
  }
  Future<Uint8List?> _load() => _images.readImage(widget.imagePath).timeout(const Duration(seconds: 8));
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Work photo'), actions: [if (widget.onDelete != null) IconButton(tooltip: 'Remove work listing', onPressed: _removing ? null : _remove, icon: const Icon(Icons.delete_outline))]),
    body: SafeArea(child: Column(children: [ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .25), child: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Text(widget.caption, textDirection: contentDirection(widget.caption), style: const TextStyle(fontSize: 14)))),
      Expanded(child: FutureBuilder<Uint8List?>(future: _future, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SingleChildScrollView(child: LoadingList());
        if (snapshot.hasError || snapshot.data == null) return SingleChildScrollView(child: EmptyState(icon: Icons.broken_image_outlined, title: 'Photo not available on this device',
          message: 'A local file reference is not an upload. Ask the worker to share work evidence through an approved channel.', action: OutlinedButton(onPressed: () => setState(() { _future = _load(); }), child: const Text('Retry local file'))));
        return InteractiveViewer(minScale: 1, maxScale: 4, child: Center(child: Image.memory(snapshot.data!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('This file is not a readable image.'))));
      })),
    ])),
  );
}
class LocalPhotoThumb extends StatelessWidget {
  final String path;
  final LocalImageStore? imageStore;
  const LocalPhotoThumb({super.key, required this.path, this.imageStore});
  @override
  Widget build(BuildContext context) => SizedBox(height: 140, width: double.infinity, child: FutureBuilder<Uint8List?>(future: (imageStore ?? const LocalImageStore()).readImage(path).timeout(const Duration(seconds: 8)), builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const ColoredBox(color: AppTheme.borderGray, child: Center(child: Text('Loading local photo…')));
    if (snapshot.hasError || snapshot.data == null) return const ColoredBox(color: AppTheme.bgLight, child: Center(child: Text('Photo not on this device', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textMuted))));
    return Image.memory(snapshot.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted)));
  }));
}
