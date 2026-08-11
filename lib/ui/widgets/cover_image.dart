import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Exibe a capa do jogo a partir do caminho local em disco, com fallback
/// elegante quando ainda nao existe capa.
class CoverImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final String fallbackLabel;

  const CoverImage({
    super.key,
    this.path,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fallbackLabel = '?',
  });

  @override
  Widget build(BuildContext context) {
    final file = path != null ? File(path!) : null;
    final hasFile = file != null && file.existsSync();

    Widget child;
    if (hasFile) {
      child = Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      child = _placeholder();
    }

    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppTheme.surfaceHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videogame_asset_outlined,
              color: AppTheme.textFaint,
              size: (width ?? 96) * 0.35,
            ),
            const SizedBox(height: 6),
            Text(
              fallbackLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textFaint,
                fontSize: (width ?? 96) * 0.14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
