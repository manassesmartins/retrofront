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

  static void setFullscreen(bool fullscreen) {
    if (!Platform.isAndroid) return;
    SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        systemNavigationBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  /// Chamada na inicializacao para garantir o comportamento padrao.
  static void bootstrap() {
    lockLandscape();
    setFullscreen(true);
  }
}
