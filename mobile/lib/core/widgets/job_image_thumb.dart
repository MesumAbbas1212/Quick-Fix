import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/local_image_store.dart';

/// Shows the first uploaded photo of a job inside list cards. Falls back to
/// a category icon when the job has no photos or the file is missing so
/// both the client and the worker always see something meaningful.
class JobImageThumb extends StatelessWidget {
  final String? image;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;
  final LocalImageStore? imageStore;

  const JobImageThumb({
    super.key,
    this.image,
    this.fallbackIcon = Icons.handyman,
    this.fallbackColor = AppTheme.brandBlue,
    this.size = 44,
    this.imageStore,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(fallbackIcon, color: fallbackColor, size: size * 0.5),
    );

    final path = image;
    if (path == null || path.isEmpty) return fallback;

    return FutureBuilder<Uint8List?>(
      future: (imageStore ?? const LocalImageStore()).readImage(path),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return fallback;
        return Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderGray),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
