import 'package:flutter/material.dart';

import '../theme.dart';

/// Logotipos de sistemas empacotados no bundle (brancos sobre transparente),
/// convertidos do conjunto oficial de logos do ES-DE
/// (gitlab.com/es-de/themes/system-logos). Sistemas sem logo próprio
/// voltam ao wordmark em texto.
const Map<String, String> _systemLogos = {
  '3do': 'assets/systems/logos/3do.png',
  'adam': 'assets/systems/logos/adam.png',
  'ags': 'assets/systems/logos/ags.png',
  'amiga': 'assets/systems/logos/amiga.png',
  'amiga1200': 'assets/systems/logos/amiga1200.png',
  'amiga600': 'assets/systems/logos/amiga600.png',
  'amigacd32': 'assets/systems/logos/amigacd32.png',
  'amstradcpc': 'assets/systems/logos/amstradcpc.png',
  'android': 'assets/systems/logos/android.png',
  'androidapps': 'assets/systems/logos/androidapps.png',
  'androidgames': 'assets/systems/logos/androidgames.png',
  'apple2': 'assets/systems/logos/apple2.png',
  'apple2gs': 'assets/systems/logos/apple2gs.png',
  'arcade': 'assets/systems/logos/arcade.png',
  'arcadia': 'assets/systems/logos/arcadia.png',
  'archimedes': 'assets/systems/logos/archimedes.png',
  'arduboy': 'assets/systems/logos/arduboy.png',
  'astrocde': 'assets/systems/logos/astrocde.png',
  'atari2600': 'assets/systems/logos/atari2600.png',
  'atari5200': 'assets/systems/logos/atari5200.png',
  'atari7800': 'assets/systems/logos/atari7800.png',
  'atari800': 'assets/systems/logos/atari800.png',
  'atarijaguar': 'assets/systems/logos/atarijaguar.png',
  'atarijaguarcd': 'assets/systems/logos/atarijaguarcd.png',
  'atarilynx': 'assets/systems/logos/atarilynx.png',
  'atarist': 'assets/systems/logos/atarist.png',
  'atarixe': 'assets/systems/logos/atarixe.png',
  'atomiswave': 'assets/systems/logos/atomiswave.png',
  'bbcmicro': 'assets/systems/logos/bbcmicro.png',
  'c64': 'assets/systems/logos/c64.png',
  'cdimono1': 'assets/systems/logos/cdimono1.png',
  'cdtv': 'assets/systems/logos/cdtv.png',
  'chailove': 'assets/systems/logos/chailove.png',
  'channelf': 'assets/systems/logos/channelf.png',
  'coco': 'assets/systems/logos/coco.png',
  'colecovision': 'assets/systems/logos/colecovision.png',
  'consolearcade': 'assets/systems/logos/consolearcade.png',
  'cps': 'assets/systems/logos/cps.png',
  'cps1': 'assets/systems/logos/cps1.png',
  'cps2': 'assets/systems/logos/cps2.png',
  'cps3': 'assets/systems/logos/cps3.png',
  'crvision': 'assets/systems/logos/crvision.png',
  'daphne': 'assets/systems/logos/daphne.png',
  'desktop': 'assets/systems/logos/desktop.png',
  'doom': 'assets/systems/logos/doom.png',
  'dos': 'assets/systems/logos/dos.png',
  'dragon32': 'assets/systems/logos/dragon32.png',
  'dreamcast': 'assets/systems/logos/dreamcast.png',
  'easyrpg': 'assets/systems/logos/easyrpg.png',
  'electron': 'assets/systems/logos/electron.png',
  'emulators': 'assets/systems/logos/emulators.png',
  'epic': 'assets/systems/logos/epic.png',
  'famicom': 'assets/systems/logos/famicom.png',
  'fba': 'assets/systems/logos/fba.png',
  'fbneo': 'assets/systems/logos/fbneo.png',
  'fds': 'assets/systems/logos/fds.png',
  'flash': 'assets/systems/logos/flash.png',
  'fm7': 'assets/systems/logos/fm7.png',
  'fmtowns': 'assets/systems/logos/fmtowns.png',
  'fpinball': 'assets/systems/logos/fpinball.png',
  'gamate': 'assets/systems/logos/gamate.png',
  'gameandwatch': 'assets/systems/logos/gameandwatch.png',
  'gamecom': 'assets/systems/logos/gamecom.png',
  'gamegear': 'assets/systems/logos/gamegear.png',
  'gb': 'assets/systems/logos/gb.png',
  'gba': 'assets/systems/logos/gba.png',
  'gbc': 'assets/systems/logos/gbc.png',
  'gc': 'assets/systems/logos/gc.png',
  'genesis': 'assets/systems/logos/genesis.png',
  'gmaster': 'assets/systems/logos/gmaster.png',
  'gx4000': 'assets/systems/logos/gx4000.png',
  'intellivision': 'assets/systems/logos/intellivision.png',
  'j2me': 'assets/systems/logos/j2me.png',
  'kodi': 'assets/systems/logos/kodi.png',
  'laserdisc': 'assets/systems/logos/laserdisc.png',
  'lcdgames': 'assets/systems/logos/lcdgames.png',
  'lowresnx': 'assets/systems/logos/lowresnx.png',
  'lutris': 'assets/systems/logos/lutris.png',
  'lutro': 'assets/systems/logos/lutro.png',
  'macintosh': 'assets/systems/logos/macintosh.png',
  'mame': 'assets/systems/logos/mame.png',
  'mame-advmame': 'assets/systems/logos/mame-advmame.png',
  'mark3': 'assets/systems/logos/mark3.png',
  'mastersystem': 'assets/systems/logos/mastersystem.png',
  'megacd': 'assets/systems/logos/megacd.png',
  'megacdjp': 'assets/systems/logos/megacdjp.png',
  'megadrive': 'assets/systems/logos/megadrive.png',
  'megadrivejp': 'assets/systems/logos/megadrivejp.png',
  'megaduck': 'assets/systems/logos/megaduck.png',
  'mess': 'assets/systems/logos/mess.png',
  'model2': 'assets/systems/logos/model2.png',
  'model3': 'assets/systems/logos/model3.png',
  'moto': 'assets/systems/logos/moto.png',
  'msx': 'assets/systems/logos/msx.png',
  'msx1': 'assets/systems/logos/msx1.png',
  'msx2': 'assets/systems/logos/msx2.png',
  'msxturbor': 'assets/systems/logos/msxturbor.png',
  'mugen': 'assets/systems/logos/mugen.png',
  'multivision': 'assets/systems/logos/multivision.png',
  'n3ds': 'assets/systems/logos/n3ds.png',
  'n64': 'assets/systems/logos/n64.png',
  'n64dd': 'assets/systems/logos/n64dd.png',
  'naomi': 'assets/systems/logos/naomi.png',
  'naomi2': 'assets/systems/logos/naomi2.png',
  'naomigd': 'assets/systems/logos/naomigd.png',
  'nds': 'assets/systems/logos/nds.png',
  'neogeo': 'assets/systems/logos/neogeo.png',
  'neogeocd': 'assets/systems/logos/neogeocd.png',
  'neogeocdjp': 'assets/systems/logos/neogeocdjp.png',
  'nes': 'assets/systems/logos/nes.png',
  'ngage': 'assets/systems/logos/ngage.png',
  'ngp': 'assets/systems/logos/ngp.png',
  'ngpc': 'assets/systems/logos/ngpc.png',
  'odyssey2': 'assets/systems/logos/odyssey2.png',
  'openbor': 'assets/systems/logos/openbor.png',
  'oric': 'assets/systems/logos/oric.png',
  'palm': 'assets/systems/logos/palm.png',
  'pc': 'assets/systems/logos/pc.png',
  'pc88': 'assets/systems/logos/pc88.png',
  'pc98': 'assets/systems/logos/pc98.png',
  'pcarcade': 'assets/systems/logos/pcarcade.png',
  'pcengine': 'assets/systems/logos/pcengine.png',
  'pcenginecd': 'assets/systems/logos/pcenginecd.png',
  'pcfx': 'assets/systems/logos/pcfx.png',
  'pico8': 'assets/systems/logos/pico8.png',
  'plus4': 'assets/systems/logos/plus4.png',
  'pokemini': 'assets/systems/logos/pokemini.png',
  'ports': 'assets/systems/logos/ports.png',
  'ps2': 'assets/systems/logos/ps2.png',
  'ps3': 'assets/systems/logos/ps3.png',
  'ps4': 'assets/systems/logos/ps4.png',
  'psp': 'assets/systems/logos/psp.png',
  'psvita': 'assets/systems/logos/psvita.png',
  'psx': 'assets/systems/logos/psx.png',
  'pv1000': 'assets/systems/logos/pv1000.png',
  'quake': 'assets/systems/logos/quake.png',
  'samcoupe': 'assets/systems/logos/samcoupe.png',
  'satellaview': 'assets/systems/logos/satellaview.png',
  'saturn': 'assets/systems/logos/saturn.png',
  'saturnjp': 'assets/systems/logos/saturnjp.png',
  'scummvm': 'assets/systems/logos/scummvm.png',
  'scv': 'assets/systems/logos/scv.png',
  'sega32x': 'assets/systems/logos/sega32x.png',
  'sega32xjp': 'assets/systems/logos/sega32xjp.png',
  'sega32xna': 'assets/systems/logos/sega32xna.png',
  'segacd': 'assets/systems/logos/segacd.png',
  'sfc': 'assets/systems/logos/sfc.png',
  'sg-1000': 'assets/systems/logos/sg-1000.png',
  'sgb': 'assets/systems/logos/sgb.png',
  'snes': 'assets/systems/logos/snes.png',
  'snesna': 'assets/systems/logos/snesna.png',
  'solarus': 'assets/systems/logos/solarus.png',
  'spectravideo': 'assets/systems/logos/spectravideo.png',
  'steam': 'assets/systems/logos/steam.png',
  'stv': 'assets/systems/logos/stv.png',
  'sufami': 'assets/systems/logos/sufami.png',
  'supergrafx': 'assets/systems/logos/supergrafx.png',
  'supervision': 'assets/systems/logos/supervision.png',
  'supracan': 'assets/systems/logos/supracan.png',
  'switch': 'assets/systems/logos/switch.png',
  'symbian': 'assets/systems/logos/symbian.png',
  'tanodragon': 'assets/systems/logos/tanodragon.png',
  'tg16': 'assets/systems/logos/tg16.png',
  'tg-cd': 'assets/systems/logos/tg-cd.png',
  'ti99': 'assets/systems/logos/ti99.png',
  'tic80': 'assets/systems/logos/tic80.png',
  'to8': 'assets/systems/logos/to8.png',
  'triforce': 'assets/systems/logos/triforce.png',
  'trs-80': 'assets/systems/logos/trs-80.png',
  'type-x': 'assets/systems/logos/type-x.png',
  'uzebox': 'assets/systems/logos/uzebox.png',
  'vectrex': 'assets/systems/logos/vectrex.png',
  'vic20': 'assets/systems/logos/vic20.png',
  'videopac': 'assets/systems/logos/videopac.png',
  'vircon32': 'assets/systems/logos/vircon32.png',
  'virtualboy': 'assets/systems/logos/virtualboy.png',
  'vpinball': 'assets/systems/logos/vpinball.png',
  'vsmile': 'assets/systems/logos/vsmile.png',
  'wasm4': 'assets/systems/logos/wasm4.png',
  'wii': 'assets/systems/logos/wii.png',
  'wiiu': 'assets/systems/logos/wiiu.png',
  'windows': 'assets/systems/logos/windows.png',
  'windows3x': 'assets/systems/logos/windows3x.png',
  'windows9x': 'assets/systems/logos/windows9x.png',
  'wonderswan': 'assets/systems/logos/wonderswan.png',
  'wonderswancolor': 'assets/systems/logos/wonderswancolor.png',
  'x1': 'assets/systems/logos/x1.png',
  'x68000': 'assets/systems/logos/x68000.png',
  'xbox': 'assets/systems/logos/xbox.png',
  'xbox360': 'assets/systems/logos/xbox360.png',
  'xboxone': 'assets/systems/logos/xboxone.png',
  'zmachine': 'assets/systems/logos/zmachine.png',
  'zx81': 'assets/systems/logos/zx81.png',
  'zxnext': 'assets/systems/logos/zxnext.png',
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
