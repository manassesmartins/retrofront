import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/screen_mode.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Interface "console": paisagem e tela cheia imersiva como padrao.
  if (!kIsWeb) {
    ScreenMode.bootstrap();
  }

  runApp(const RetroFrontApp());
}
