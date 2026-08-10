import 'package:flutter/material.dart';

import 'app.dart';
import 'core/screen_mode.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Interface "console": paisagem e tela cheia imersiva como padrao.
  ScreenMode.bootstrap();

  runApp(const RetroFrontApp());
}
