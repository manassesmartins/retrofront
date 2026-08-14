import 'dart:async';

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
  StreamSubscription<GamepadAction>? _soundSub;

  @override
  void initState() {
    super.initState();
    _services = AppServices.build();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _SplashScreen(),
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
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_esports, size: 72, color: AppTheme.accent),
            SizedBox(height: 20),
            CircularProgressIndicator(color: AppTheme.accent),
          ],
        ),
      ),
    );
  }
}
