import 'package:flutter/material.dart';

/// Ação confirmada de uma opção de configuração. Recebe o contexto para abrir
/// diálogos/seletores (ex.: digitar uma chave, escolher uma pasta).
typedef SettingsConfirm = Future<void> Function(BuildContext context);

/// Uma opção de configuração dentro de uma categoria. Pode ter ciclo de
/// valores, liga/desliga e/ou uma confirmação (diálogo/arquivo).
class SettingsOption {
  final String label;
  final String description;

  /// Texto exibido ao lado do nome (valor atual da opção).
  final String Function() display;

  /// Lista de valores cíclicos: (valor interno, rótulo exibido).
  final List<(dynamic, String)>? cycleValues;
  final int Function()? currentIndex;
  final void Function(int)? onCycle;

  final bool Function()? toggle;
  final void Function(bool)? onToggle;

  final SettingsConfirm? onConfirm;

  const SettingsOption({
    required this.label,
    this.description = '',
    this.display = _emptyText,
    this.cycleValues,
    this.currentIndex,
    this.onCycle,
    this.toggle,
    this.onToggle,
    this.onConfirm,
  });

  static String _emptyText() => '';

  int get count => cycleValues?.length ?? 0;
  int get index => currentIndex?.call() ?? 0;
  bool get toggleValue => toggle?.call() ?? false;
  String get valueText => display();
}

/// Categoria de configurações exibida no carrossel; cada categoria é aberta
/// como uma tela própria (janela) com suas opções.
class SettingsCategory {
  final String label;
  final String description;
  final IconData icon;
  final List<SettingsOption> options;

  const SettingsCategory({
    required this.label,
    required this.description,
    required this.icon,
    required this.options,
  });
}
