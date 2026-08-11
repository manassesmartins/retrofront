import 'dart:io';

import 'package:flutter/services.dart';

/// Aplica o modo "console": orientacao paisagem e tela cheia imersiva.
/// Em desktop nao tem efeito (a janela e controlada pelo sistema).
class ScreenMode {
  ScreenMode._();

  static void lockLandscape() {
    if (Platform.isAndroid) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  static void setFullscreen(bool fullscreen, {bool dark = true}) {
    if (!Platform.isAndroid) return;
    SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: const Color(0x00000000),
        statusBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  /// Atualiza o estilo das barras do sistema conforme o tema.
  static void setThemeMode({required bool dark}) {
    setFullscreen(true, dark: dark);
  }

  /// Chamada na inicializacao para garantir o comportamento padrao.
  static void bootstrap() {
    lockLandscape();
    setFullscreen(true);
  }
}
