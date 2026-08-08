import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Fundo "console": imagem de capa desfocada e escurecida cobrindo a tela toda,
/// ou um gradiente na cor do sistema quando nao ha capa disponivel.
class CoverBackdrop extends StatelessWidget {
  /// Caminho absoluto de uma capa no disco. Se nulo/inexistente usa [color].
  final String? coverPath;

  /// Cor de fallback (geralmente a cor do sistema) para o gradiente.
  final Color color;

  const CoverBackdrop({
    super.key,
    this.coverPath,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final path = coverPath;
    final file = (path != null && path.isNotEmpty) ? File(path) : null;
    final hasCover = file != null && file.existsSync();

    Widget base = DecoratedBox(
      decoration: BoxDecoration(gradient: AppTheme.systemGradient(color)),
    );

    if (hasCover) {
      base = Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 640,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // Escurece e equilibra para manter contraste com o texto.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(color, Colors.black, 0.72)!,
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        // Vinheta sutil para dar profundidade.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.35,
              colors: [Colors.transparent, Color(0x66000000)],
              stops: [0.72, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
