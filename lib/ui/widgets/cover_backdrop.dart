import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Fundo "console": imagem de capa desfocada e escurecida cobrindo a tela toda,
/// ou um gradiente na cor do sistema quando nao ha capa disponivel. A arte
/// opcional da pasta SYSTEMART e sobreposta ao gradiente a 30% de opacidade.
class CoverBackdrop extends StatelessWidget {
  /// Caminho absoluto de uma capa no disco. Se nulo/inexistente usa [color].
  final String? coverPath;

  /// Arte de fundo do console (pasta SYSTEMART), exibida a 30% de opacidade
  /// sobre o gradiente. Se nula/inexistente usa apenas o gradiente.
  final String? artPath;

  /// Cor de fallback (geralmente a cor do sistema) para o gradiente.
  final Color color;

  /// Escurece o gradiente de fallback (0 = nada, 1 = preto) para dar
  /// contraste extra ao conteudo.
  final double darken;

  const CoverBackdrop({
    super.key,
    this.coverPath,
    this.artPath,
    required this.color,
    this.darken = 0,
  });

  @override
  Widget build(BuildContext context) {
    final path = coverPath;
    final file = (path != null && path.isNotEmpty) ? File(path) : null;
    final hasCover = file != null && file.existsSync();
    final dark = AppTheme.isDark;

    Widget base = DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.systemGradient(
          Color.lerp(
            color,
            dark ? Colors.black : Colors.white,
            darken.clamp(0.0, 1.0),
          ) ??
              color,
        ),
      ),
    );

    // Arte do console (SYSTEMART) a 30% de opacidade sobre o gradiente.
    final artFile = artPath != null ? File(artPath!) : null;
    if (artFile != null && artFile.existsSync()) {
      base = Stack(
        fit: StackFit.expand,
        children: [
          base,
          Opacity(
            opacity: 0.30,
            child: Image.file(
              artFile,
              fit: BoxFit.cover,
              cacheWidth: 720,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }

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
          // Equilibra o brilho da capa para manter contraste com o texto.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        Color.lerp(color, Colors.black, 0.72)!,
                        Colors.black.withValues(alpha: 0.72),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.66),
                        Colors.white.withValues(alpha: 0.74),
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
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.35,
              colors: dark
                  ? [Colors.transparent, const Color(0x66000000)]
                  : [Colors.transparent, const Color(0x14000000)],
              stops: const [0.72, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
