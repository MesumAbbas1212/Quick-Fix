import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/local_image_store.dart';

/// Circular avatar with image, initials fallback, size, optional online dot
/// and border color. Network URLs load via [Image.network]; local file paths
/// load from disk via [imageLoader] (defaults to [LocalImageStore.readImage]).
class UserAvatar extends StatelessWidget {
  final String fullName;
  final String? avatarUrl;
  final double size;
  final bool online;
  final Color? borderColor;
  final Future<Uint8List?> Function(String path)? imageLoader;

  const UserAvatar({
    super.key,
    required this.fullName,
    this.avatarUrl,
    this.size = 48,
    this.online = false,
    this.borderColor,
    this.imageLoader,
  });

  String get _initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final border = borderColor != null ? Border.all(color: borderColor!, width: 2) : null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            key: const Key('avatar-circle'),
            constraints: BoxConstraints.tightFor(width: size, height: size),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bgLight,
              border: border,
            ),
            child: _avatar(),
          ),
          if (online)
            Positioned(
              key: const Key('avatar-online-dot'),
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.successGreen,
                  border: Border.all(color: AppTheme.surfaceWhite, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final url = avatarUrl;
    if (url == null || url.isEmpty) return _initialsCircle(size);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialsCircle(size),
      );
    }
    final loader = imageLoader ?? LocalImageStore().readImage;
    return FutureBuilder<Uint8List?>(
      future: loader(url),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return _initialsCircle(size);
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }

  Widget _initialsCircle(double size) {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppTheme.brandBlue,
        ),
      ),
    );
  }
}
