import 'package:flutter/material.dart';

import '../theme.dart';

/// Logotipos de sistemas empacotados no bundle (brancos sobre transparente),
/// extraídos do conjunto "Monochrome Gaming Logos" (HVR88). Sistemas sem logo
/// próprio voltam ao wordmark em texto.
const Map<String, String> _systemLogos = {
  '3do': 'assets/systems/logos/3do.png',
  'amiga': 'assets/systems/logos/amiga.png',
  'amigacd32': 'assets/systems/logos/amigacd32.png',
  'amstradcpc': 'assets/systems/logos/amstradcpc.png',
  'apple2': 'assets/systems/logos/apple2.png',
  'arcade': 'assets/systems/logos/arcade.png',
  'atari2600': 'assets/systems/logos/atari2600.png',
  'atari5200': 'assets/systems/logos/atari5200.png',
  'atari7800': 'assets/systems/logos/atari7800.png',
  'atari800': 'assets/systems/logos/atari800.png',
  'atarijaguar': 'assets/systems/logos/atarijaguar.png',
  'atarilynx': 'assets/systems/logos/atarilynx.png',
  'atarist': 'assets/systems/logos/atarist.png',
  'c64': 'assets/systems/logos/c64.png',
  'colecovision': 'assets/systems/logos/colecovision.png',
  'cps1': 'assets/systems/logos/cps1.png',
  'cps2': 'assets/systems/logos/cps2.png',
  'dos': 'assets/systems/logos/dos.png',
  'dreamcast': 'assets/systems/logos/dreamcast.png',
  'famicom': 'assets/systems/logos/famicom.png',
  'fds': 'assets/systems/logos/fds.png',
  'gameandwatch': 'assets/systems/logos/gameandwatch.png',
  'gb': 'assets/systems/logos/gb.png',
  'gba': 'assets/systems/logos/gba.png',
  'gbc': 'assets/systems/logos/gbc.png',
  'gc': 'assets/systems/logos/gc.png',
  'genesis': 'assets/systems/logos/genesis.png',
  'gg': 'assets/systems/logos/gg.png',
  'intellivision': 'assets/systems/logos/intellivision.png',
  'jaguar': 'assets/systems/logos/jaguar.png',
  'lynx': 'assets/systems/logos/lynx.png',
  'mame': 'assets/systems/logos/mame.png',
  'master': 'assets/systems/logos/master.png',
  'msx': 'assets/systems/logos/msx.png',
  'msx2': 'assets/systems/logos/msx2.png',
  'n3ds': 'assets/systems/logos/n3ds.png',
  'n64': 'assets/systems/logos/n64.png',
  'nds': 'assets/systems/logos/nds.png',
  'neogeo': 'assets/systems/logos/neogeo.png',
  'nes': 'assets/systems/logos/nes.png',
  'ngp': 'assets/systems/logos/ngp.png',
  'ngpc': 'assets/systems/logos/ngpc.png',
  'odyssey2': 'assets/systems/logos/odyssey2.png',
  'pce': 'assets/systems/logos/pce.png',
  'pcecd': 'assets/systems/logos/pcecd.png',
  'pcfx': 'assets/systems/logos/pcfx.png',
  'ps2': 'assets/systems/logos/ps2.png',
  'psp': 'assets/systems/logos/psp.png',
  'psx': 'assets/systems/logos/psx.png',
  'saturn': 'assets/systems/logos/saturn.png',
  'sega32x': 'assets/systems/logos/sega32x.png',
  'segacd': 'assets/systems/logos/segacd.png',
  'sg1000': 'assets/systems/logos/sg1000.png',
  'snes': 'assets/systems/logos/snes.png',
  'switch': 'assets/systems/logos/switch.png',
  'vb': 'assets/systems/logos/vb.png',
  'wii': 'assets/systems/logos/wii.png',
  'wiiu': 'assets/systems/logos/wiiu.png',
  'wonderswan': 'assets/systems/logos/wonderswan.png',
  'wonderswancolor': 'assets/systems/logos/wonderswancolor.png',
  'xbox': 'assets/systems/logos/xbox.png',
  'xbox360': 'assets/systems/logos/xbox360.png',
  'zxspectrum': 'assets/systems/logos/zxspectrum.png',
};

/// Caminho do logo de um sistema no bundle, ou null se não houver (neste caso
/// a capa volta ao wordmark em texto).
String? systemLogoPath(String name) => _systemLogos[name];

/// Capa de um sistema para o carrossel: caixa 3:4 com a cor do console, logo
/// do sistema (branco sobre transparente) e quantidade de jogos. Sistemas sem
/// logo exibem o wordmark em texto. O estado [selected] destaca com brilho.
class SystemCover extends StatelessWidget {
  final String name;
  final String fullName;
  final Color color;
  final int gameCount;
  final bool showGameCount;
  final bool selected;
  final VoidCallback onTap;

  const SystemCover({
    super.key,
    required this.name,
    required this.fullName,
    required this.color,
    required this.gameCount,
    this.showGameCount = true,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final logoPath = systemLogoPath(name);

    return AnimatedScale(
      scale: selected ? 1.0 : 0.84,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: selected ? 1.0 : 0.42,
        duration: const Duration(milliseconds: 220),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, AppTheme.darken(color, 0.45)],
              ),
              border: Border.all(
                color: selected ? Colors.white : Colors.white12,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: logoPath != null
                    ? _LogoLayout(
                        logoPath: logoPath,
                        gameCount: gameCount,
                        showGameCount: showGameCount,
                      )
                    : _TextLayout(
                        name: name,
                        fullName: fullName,
                        gameCount: gameCount,
                        showGameCount: showGameCount,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout com o logotipo do console ocupando o espaço principal, estilo ES-DE.
class _LogoLayout extends StatelessWidget {
  final String logoPath;
  final int gameCount;
  final bool showGameCount;

  const _LogoLayout({
    required this.logoPath,
    required this.gameCount,
    required this.showGameCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Image.asset(
              logoPath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        if (showGameCount) ...[
          const SizedBox(height: 8),
          Center(child: _GameCountBadge(count: gameCount)),
        ],
      ],
    );
  }
}

/// Layout em texto (wordmark) para sistemas sem logo próprio.
class _TextLayout extends StatelessWidget {
  final String name;
  final String fullName;
  final int gameCount;
  final bool showGameCount;

  const _TextLayout({
    required this.name,
    required this.fullName,
    required this.gameCount,
    required this.showGameCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Text(
          name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: (26 + name.length * -2.2).clamp(18.0, 34.0),
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          fullName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (showGameCount) _GameCountBadge(count: gameCount),
      ],
    );
  }
}

class _GameCountBadge extends StatelessWidget {
  final int count;

  const _GameCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count ${count == 1 ? 'jogo' : 'jogos'}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
