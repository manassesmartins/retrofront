import 'package:flutter/material.dart';

import 'core/app_scope.dart';
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

  @override
  void initState() {
    super.initState();
    _services = AppServices.build();
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
