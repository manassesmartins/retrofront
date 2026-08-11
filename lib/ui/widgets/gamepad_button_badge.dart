import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../theme.dart';

/// Insignia que representa um botao fisico de controle (A, B, Start, D-Pad…),
/// usado nos atalhos de navegacao exibidos na interface.
class GamepadButtonBadge extends StatelessWidget {
  final GamepadButton button;
  final double size;
  final Color color;

  const GamepadButtonBadge({
    super.key,
    required this.button,
    this.size = 17,
    this.color = const Color(0xFF9AA3B2),
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: color, width: 1.2);
    switch (button) {
      case GamepadButton.a:
      case GamepadButton.b:
      case GamepadButton.x:
      case GamepadButton.y:
        return _circle(border, child: _letter(button));
      case GamepadButton.dpadUp:
        return _circle(border, child: Icon(Icons.arrow_upward, color: color, size: size * 0.72));
      case GamepadButton.dpadDown:
        return _circle(border, child: Icon(Icons.arrow_downward, color: color, size: size * 0.72));
      case GamepadButton.dpadLeft:
        return _circle(border, child: Icon(Icons.arrow_back, color: color, size: size * 0.72));
      case GamepadButton.dpadRight:
        return _circle(border, child: Icon(Icons.arrow_forward, color: color, size: size * 0.72));
      case GamepadButton.start:
        return _pill(border, child: Icon(Icons.menu, color: color, size: size * 0.52));
      case GamepadButton.back:
        return _pill(border);
      case GamepadButton.home:
        return _circle(border, child: Icon(Icons.home, color: color, size: size * 0.6));
      case GamepadButton.leftBumper:
        return _pill(border, label: 'LB');
      case GamepadButton.rightBumper:
        return _pill(border, label: 'RB');
      case GamepadButton.leftTrigger:
        return _pill(border, label: 'LT');
      case GamepadButton.rightTrigger:
        return _pill(border, label: 'RT');
      case GamepadButton.leftStick:
        return _circle(border, child: _letter(GamepadButton.leftStick));
      case GamepadButton.rightStick:
        return _circle(border, child: _letter(GamepadButton.rightStick));
      case GamepadButton.touchpad:
        return _pill(border, wide: true);
    }
  }

  Widget _letter(GamepadButton button) {
    return Text(
      switch (button) {
        GamepadButton.a => 'A',
        GamepadButton.b => 'B',
        GamepadButton.x => 'X',
        GamepadButton.y => 'Y',
        GamepadButton.leftStick => 'L',
        GamepadButton.rightStick => 'R',
        _ => '?',
      },
      style: TextStyle(
        color: color,
        fontSize: size * 0.56,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }

  Widget _circle(Border border, {required Widget child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fill(),
        border: border,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _pill(Border border, {String? label, bool wide = false, Widget? child}) {
    final width = wide ? size * 1.9 : size * 1.45;
    return Container(
      width: width,
      height: size * 0.74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size),
        color: _fill(),
        border: border,
      ),
      alignment: Alignment.center,
      child: label != null
          ? Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: size * 0.48,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            )
          : child,
    );
  }

  Color _fill() {
    return AppTheme.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
  }
}
