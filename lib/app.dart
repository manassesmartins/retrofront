import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_scope.dart';
import 'core/route_observer.dart';
import 'gamepad/gamepad_manager.dart';
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
          child: ValueListenableBuilder<bool>(
            valueListenable: services.darkMode,
            builder: (context, dark, _) {
              return MaterialApp(
                title: 'RetroFront',
                debugShowCheckedModeBanner: false,
                navigatorObservers: [routeObserver],
                theme: AppTheme.dark(),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                home: const SystemView(),
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
    return const Scaffold(
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
