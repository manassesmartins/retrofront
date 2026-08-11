import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../gamepad/gamepad_manager.dart';
import '../theme.dart';

/// Ação de uma tecla especial do teclado virtual (não caractere).
enum VkAction { backspace, space, shift, sym, done }

/// Tecla do teclado virtual: um caractere ou uma ação.
class VkKey {
  final String? char;
  final VkAction? action;
  final int colspan;

  const VkKey.char(this.char, {this.colspan = 1}) : action = null;
  const VkKey.action(this.action, {this.colspan = 1}) : char = null;

  bool get isAction => action != null;

  @override
  bool operator ==(Object other) =>
      other is VkKey &&
      other.char == char &&
      other.action == action &&
      other.colspan == colspan;

  @override
  int get hashCode => Object.hash(char, action, colspan);
}

/// Layout de um idioma para o teclado virtual.
class VkLayout {
  final String id;
  final String label;

  /// Letras acentuadas específicas do idioma (linhas extras na página de
  /// símbolos, com até 10 teclas por linha).
  final List<String> accentRows;

  /// Linhas de letras (caixa baixa); o teclado gera a versão maiúscula.
  final List<String> letterRows;

  /// Linhas de números/símbolos.
  final List<String> symbolRows;

  const VkLayout({
    required this.id,
    required this.label,
    this.accentRows = const [],
    required this.letterRows,
    required this.symbolRows,
  });

  /// Layout padrão para um id de idioma (fallback: English).
  static VkLayout ofLanguage(String? id) {
    for (final l in _layouts) {
      if (l.id.toLowerCase() == (id ?? '').toLowerCase()) return l;
    }
    return _english;
  }

  static final List<VkLayout> _layouts = [
    const VkLayout(
      id: 'pt-BR',
      label: 'Português',
      accentRows: ['áàâãéêíóôõ', 'úüç'],
      letterRows: ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'],
      symbolRows: [
        '1234567890',
        '-/:;()&@#%',
        '.,?!\'"+*=_',
      ],
    ),
    _english,
    const VkLayout(
      id: 'es-ES',
      label: 'Español',
      accentRows: ['áéíóúñü'],
      letterRows: ['qwertyuiop', 'asdfghjkl', 'ñzxcvbnm'],
      symbolRows: [
        '1234567890',
        '-/:;()&@#%',
        '.,?!\'"+*=_',
      ],
    ),
    const VkLayout(
      id: 'fr-FR',
      label: 'Français',
      accentRows: ['àâçéèêëîïô', 'ùûüœ'],
      letterRows: ['azertyuiop', 'qsdfghjklm', 'wxcvbn'],
      symbolRows: [
        '1234567890',
        '-/:;()&@#%',
        '.,?!\'"+*=_',
      ],
    ),
    const VkLayout(
      id: 'de-DE',
      label: 'Deutsch',
      accentRows: ['äöüß'],
      letterRows: ['qwertzuiop', 'asdfghjkl', 'yxcvbnm'],
      symbolRows: [
        '1234567890',
        '-/:;()&@#%',
        '.,?!\'"+*=_',
      ],
    ),
    const VkLayout(
      id: 'it-IT',
      label: 'Italiano',
      accentRows: ['àèéìòù'],
      letterRows: ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'],
      symbolRows: [
        '1234567890',
        '-/:;()&@#%',
        '.,?!\'"+*=_',
      ],
    ),
  ];

  static const VkLayout _english = VkLayout(
    id: 'en-US',
    label: 'English',
    letterRows: ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'],
    symbolRows: [
      '1234567890',
      '-/:;()&@#%',
      '.,?!\'"+*=_',
    ],
  );
}

/// Constrói a grade de teclas para a página atual (letras ou símbolos) com
/// a caixa alta aplicada quando [shift] estiver ativo. As letras seguem o
/// layout QWERTY; os acentos ficam na página de símbolos.
List<List<VkKey>> vkRows(
  VkLayout layout, {
  required bool symbols,
  required bool shift,
}) {
  final rows = <List<VkKey>>[];
  String upper(String c) => shift ? c.toUpperCase() : c;

  if (!symbols) {
    for (final line in layout.letterRows) {
      rows.add([for (final c in line.split('')) VkKey.char(upper(c))]);
    }
    rows.add(const [
      VkKey.action(VkAction.shift),
      VkKey.action(VkAction.backspace),
      VkKey.action(VkAction.sym),
      VkKey.action(VkAction.space, colspan: 3),
      VkKey.action(VkAction.done),
    ]);
  } else {
    for (final line in layout.symbolRows) {
      rows.add([for (final c in line.split('')) VkKey.char(c)]);
    }
    for (final line in layout.accentRows) {
      rows.add([for (final c in line.split('')) VkKey.char(c)]);
    }
    rows.add(const [
      VkKey.action(VkAction.sym),
      VkKey.action(VkAction.backspace),
      VkKey.action(VkAction.space, colspan: 3),
      VkKey.action(VkAction.done),
    ]);
  }
  return rows;
}

/// Teclado virtual estilo console: navegável por gamepad (setas movem, A
/// pressiona a tecla, B apaga, Start confirma, Select cancela), por teclado
/// físico e por toque. As teclas seguem o layout do idioma configurado.
class VirtualKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final String? language;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;

  const VirtualKeyboard({
    super.key,
    required this.controller,
    this.language,
    this.onChanged,
    this.onDone,
    this.onCancel,
  });

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  final FocusNode _focus = FocusNode();
  StreamSubscription<GamepadAction>? _gamepadSub;

  bool _symbols = false;
  bool _shift = false;
  int _row = 0;
  int _col = 0;
  bool _depsReady = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_notify);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _gamepadSub = AppScope.of(context).gamepad.actions.listen(_onGamepad);
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    widget.controller.removeListener(_notify);
    _focus.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged?.call(widget.controller.text);

  VkLayout get _layout => VkLayout.ofLanguage(widget.language);

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    switch (action) {
      case GamepadAction.up:
        _move(-1, 0);
      case GamepadAction.down:
        _move(1, 0);
      case GamepadAction.left:
        _move(0, -1);
      case GamepadAction.right:
        _move(0, 1);
      case GamepadAction.confirm:
        _press(_row, _col);
      case GamepadAction.back:
        _backspace();
      case GamepadAction.start:
        widget.onDone?.call();
      case GamepadAction.select:
      case GamepadAction.home:
        widget.onCancel?.call();
      case GamepadAction.pageUp:
      case GamepadAction.pageDown:
        break;
    }
  }

  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _move(-1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _move(0, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _move(0, 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _press(_row, _col);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        _insert(' ');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace:
        _backspace();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onCancel?.call();
        return KeyEventResult.handled;
      default:
        break;
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty) {
      _insert(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _move(int dr, int dc) {
    final rows = vkRows(_layout, symbols: _symbols, shift: _shift);
    if (rows.isEmpty) return;
    final nextRow = (_row + dr).clamp(0, rows.length - 1);
    final maxCol = rows[nextRow].length - 1;
    final nextCol = (_col + dc).clamp(0, maxCol);
    setState(() {
      _row = nextRow;
      _col = nextCol;
    });
  }

  void _press(int row, int col) {
    final rows = vkRows(_layout, symbols: _symbols, shift: _shift);
    if (row < 0 || row >= rows.length) return;
    final line = rows[row];
    if (col < 0 || col >= line.length) return;
    final key = line[col];

    if (!key.isAction) {
      _insert(key.char!);
      return;
    }
    switch (key.action!) {
      case VkAction.backspace:
        _backspace();
      case VkAction.space:
        _insert(' ');
      case VkAction.shift:
        setState(() => _shift = !_shift);
      case VkAction.sym:
        setState(() {
          _symbols = !_symbols;
          _shift = false;
          _row = 0;
          _col = 0;
        });
      case VkAction.done:
        widget.onDone?.call();
    }
  }

  void _insert(String ch) {
    if (ch.isEmpty) return;
    final t = widget.controller.text;
    final sel = widget.controller.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final next = t.replaceRange(start, end, ch);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    if (_shift) setState(() => _shift = false);
  }

  void _backspace() {
    final t = widget.controller.text;
    final sel = widget.controller.selection;
    var start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    if (start == end) {
      if (start == 0) return;
      start = start - 1;
    }
    final next = t.replaceRange(start, end, '');
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = vkRows(_layout, symbols: _symbols, shift: _shift);
    final maxCols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onHardwareKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows.length; r++) _keyRow(rows[r], r, maxCols),
        ],
      ),
    );
  }

  Widget _keyRow(List<VkKey> line, int rowIndex, int maxCols) {
    final cellW = (MediaQuery.of(context).size.width - 24) / maxCols;
    final cellH = (cellW * 0.9).clamp(34.0, 52.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
      child: Row(
        children: [
          for (var c = 0; c < line.length; c++)
            Expanded(
              flex: line[c].colspan,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Key(
                  key: ValueKey(
                    'vk_${_symbols ? 's' : 'l'}_${_shift ? 'u' : 'l'}_$rowIndex'
                    '_$c',
                  ),
                  label: _keyLabel(line[c]),
                  isAction: line[c].isAction,
                  selected: rowIndex == _row && c == _col,
                  active: _shift && line[c].action == VkAction.shift,
                  height: cellH,
                  onTap: () {
                    setState(() {
                      _row = rowIndex;
                      _col = c;
                    });
                    _press(rowIndex, c);
                  },
                ),
              ),
            ),
          for (var i = line.length; i < maxCols; i++) const Spacer(),
        ],
      ),
    );
  }

  String _keyLabel(VkKey key) {
    if (!key.isAction) return key.char!;
    return switch (key.action!) {
      VkAction.backspace => '⌫',
      VkAction.space => 'espaço',
      VkAction.shift => '⇧',
      VkAction.sym => _symbols ? 'abc' : '?#',
      VkAction.done => 'ok',
    };
  }
}

class _Key extends StatelessWidget {
  final String label;
  final bool isAction;
  final bool selected;
  final bool active;
  final double height;
  final VoidCallback onTap;

  const _Key({
    super.key,
    required this.label,
    required this.isAction,
    required this.selected,
    required this.active,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: active
                  ? AppTheme.accent
                  : selected
                      ? AppTheme.accent.withValues(alpha: 0.55)
                      : isAction
                          ? AppTheme.accent.withValues(alpha: 0.18)
                          : AppTheme.surfaceHigh,
              border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color:
                    active || selected ? AppTheme.onAccent : AppTheme.textPrimary,
                fontSize: height * 0.42,
                fontWeight: isAction ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo de entrada de texto com teclado virtual (para chaves, argumentos,
/// etc.). Retorna o texto digitado via pop, ou null se cancelado.
Future<String?> showVirtualKeyboardDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  bool obscure = false,
  String? language,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) {
      final controller = TextEditingController(text: initial);
      return StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          title: Row(
            children: [
              Icon(Icons.keyboard_alt_outlined,
                  color: AppTheme.accentAlt, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                onPressed: () => Navigator.of(dialogCtx).pop(),
                icon: Icon(Icons.close, color: AppTheme.textSecondary),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    obscure ? '•' * controller.text.length : controller.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                VirtualKeyboard(
                  controller: controller,
                  language: language,
                  onChanged: (_) => setState(() {}),
                  onDone: () => Navigator.of(dialogCtx).pop(controller.text),
                  onCancel: () => Navigator.of(dialogCtx).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
