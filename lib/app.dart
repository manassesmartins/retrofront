import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_dirs.dart';
import 'core/app_scope.dart';
import 'core/route_observer.dart';
import 'data/systems/system_art_installer.dart';
import 'gamepad/gamepad_manager.dart';
import 'models/theme_palette.dart';
import 'ui/system_view.dart';
import 'ui/theme.dart';

/// Raiz do aplicativo: inicializa os servicos e aplica o tema.
class RetroFrontApp extends StatefulWidget {
  const RetroFrontApp({super.key});

  @override
  State<RetroFrontApp> createState() => _RetroFrontAppState();
}

class _RetroFrontAppState extends State<RetroFrontApp> {
  late final Future<AppServices> _services;
  final _startup = ValueNotifier<StartupProgress>(
    const StartupProgress(0.0, 'Iniciando RetroFront...'),
  );
  StreamSubscription<GamepadAction>? _soundSub;

  @override
  void initState() {
    super.initState();
    _services = AppServices.build(
      onProgress: (p) => _startup.value = p,
    );
    // Registra a pasta de ROMs escolhida para derivar a pasta principal da
    // biblioteca (CONFIGS/COVERS/etc.) antes do primeiro carregamento.
    _services.then((services) {
      AppDirs.useRomsOverride(services.settings.getRomsPath());
      // Instala as artes de fundo padrão em SYSTEMART (sem sobrescrever as
      // do usuário) para os consoles terem fundo já no primeiro uso.
      SystemArtInstaller.install();
    });
    // Sons de navegação globais (liga/desliga em Configurações > Interface).
    _services.then((services) {
      _soundSub = services.gamepad.actions.listen((action) {
        if (!services.settings.getNavSounds()) return;
        switch (action) {
          case GamepadAction.up:
          case GamepadAction.down:
          case GamepadAction.left:
          case GamepadAction.right:
          case GamepadAction.confirm:
          case GamepadAction.back:
          case GamepadAction.pageUp:
          case GamepadAction.pageDown:
            SystemSound.play(SystemSoundType.click);
          default:
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _soundSub?.cancel();
    _startup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _SplashScreen(progress: _startup),
          );
        }
        final services = snapshot.data!;

        return AppScope(
          services: services,
          child: ValueListenableBuilder<ThemePalette>(
            valueListenable: services.themes.active,
            builder: (context, palette, _) {
              AppTheme.setPalette(palette);
              return ValueListenableBuilder<bool>(
                valueListenable: services.darkMode,
                builder: (context, dark, _) {
                  final lightTheme = AppTheme.build(dark: false);
                  final darkTheme = AppTheme.build(dark: true);
                  // Deixa os statics de AppTheme coerentes com o modo ativo,
                  // para os widgets que leem a paleta diretamente.
                  AppTheme.apply(dark: dark);
                  return MaterialApp(
                    title: 'RetroFront',
                    debugShowCheckedModeBanner: false,
                    navigatorObservers: [routeObserver],
                    theme: lightTheme,
                    darkTheme: darkTheme,
                    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                    home: const SystemView(),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({required this.progress});

  /// Progresso da inicializacao (barra + etapa atual).
  final ValueListenable<StartupProgress> progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Glow(
            color: AppTheme.accent.withValues(alpha: 0.16),
            alignment: const Alignment(-1.2, -1.2),
            size: 420,
          ),
          _Glow(
            color: AppTheme.accentAlt.withValues(alpha: 0.12),
            alignment: const Alignment(1.2, 1.2),
            size: 460,
          ),
          Center(
            child: ValueListenableBuilder<StartupProgress>(
              valueListenable: progress,
              builder: (context, p, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surface,
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.35),
                            blurRadius: 48,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentAlt],
                      ).createShader(bounds),
                      child: const Text(
                        'RetroFront',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    SizedBox(
                      width: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: p.value.clamp(0.02, 1.0),
                          minHeight: 8,
                          backgroundColor: AppTheme.surfaceHigh,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 320,
                      height: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Text(
                          p.label,
                          key: ValueKey(p.label),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Mancha de luz suave usada como decoracao de fundo da splash.
class _Glow extends StatelessWidget {
  final Color color;
  final Alignment alignment;
  final double size;

  const _Glow({
    required this.color,
    required this.alignment,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
