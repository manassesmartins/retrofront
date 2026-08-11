import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../theme.dart';
import 'gamepad_button_badge.dart';

/// Barra inferior com dicas de navegacao (estilo console).
class HintBar extends StatelessWidget {
  final List<Hint> hints;

  const HintBar({super.key, required this.hints});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 22,
          runSpacing: 6,
          children: [
            for (final h in hints)
              _HintChip(label: h.label, icon: h.icon, button: h.button),
          ],
        ),
      ),
    );
  }
}

class Hint {
  final String label;
  final IconData? icon;
  final GamepadButton? button;

  const Hint(this.label, {this.icon, this.button});
}

class _HintChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final GamepadButton? button;

  const _HintChip({required this.label, this.icon, this.button});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (button != null) ...[
          GamepadButtonBadge(button: button!, color: AppTheme.textFaint),
          const SizedBox(width: 6),
        ] else if (icon != null) ...[
          Icon(icon, color: AppTheme.textFaint, size: 15),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textFaint,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
