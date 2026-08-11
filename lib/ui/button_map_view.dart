import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../ui/theme.dart';
import '../ui/widgets/nav_key_handler.dart';

class ButtonMapView extends StatefulWidget {
  const ButtonMapView({super.key});

  @override
  State<ButtonMapView> createState() => _ButtonMapViewState();
}

class _ButtonMapViewState extends State<ButtonMapView> {
  AppServices get _svc => AppScope.of(context);

  late Map<GamepadButton, GamepadAction> _map;
  GamepadAction? _listening;
  StreamSubscription<GamepadAction>? _gamepadSub;
  StreamSubscription<RawGamepadEvent>? _rawSub;
  StreamSubscription<List<GamepadPlayer>>? _playersSub;
  int _selected = 0;
  bool _depsReady = false;

  List<GamepadPlayer> _players = [];

  /// Selecao de destino: 0 = "Padrao (todos)"; 1..n = controle `_players[i-1]`.
  int _sel = 0;

  GamepadPlayer? get _selPlayer =>
      _sel > 0 && _sel - 1 < _players.length ? _players[_sel - 1] : null;

  @override
  void initState() {
    super.initState();
    _map = {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
    _rawSub = _svc.gamepad.rawButtons.listen(_onRawButton);
    _playersSub = _svc.gamepad.controllers.listen(_onPlayers);
    _reloadMap();
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    _rawSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }

  void _onPlayers(List<GamepadPlayer> players) {
    if (!mounted) return;
    setState(() {
      _players = players;
      if (_sel > players.length) _sel = 0;
      _reloadMap();
    });
  }

  void _reloadMap() {
    final player = _selPlayer;
    _map = player != null
        ? Map.of(player.overrides)
        : Map.of(_svc.gamepad.defaultOverrides);
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) return;

    switch (action) {
      case GamepadAction.up:
        _move(-1);
        break;
      case GamepadAction.down:
        _move(1);
        break;
      case GamepadAction.left:
        _switchPlayer(-1);
        break;
      case GamepadAction.right:
        _switchPlayer(1);
        break;
      case GamepadAction.confirm:
        _activate();
        break;
      case GamepadAction.back:
        if (_listening == null) {
          _goBack();
        } else {
          _cancelListen();
        }
        break;
      case GamepadAction.start:
      case GamepadAction.home:
        _goBack();
        break;
      default:
        break;
    }
  }

  void _switchPlayer(int delta) {
    if (_listening != null) return;
    final count = 1 + _players.length;
    final next = (_sel + delta + count) % count;
    if (next == _sel) return;
    setState(() {
      _sel = next;
      _reloadMap();
    });
  }

  void _onRawButton(RawGamepadEvent event) {
    if (_listening == null) return;
    final player = _selPlayer;
    // Ao configurar um controle especifico, ignora botoes de outros controles.
    if (player != null && event.gamepadId != player.id) return;
    if (!_map.containsKey(event.button)) {
      final oldAction = _listening;
      if (oldAction != null) {
        final keysToRemove = _map.entries
            .where((e) => e.value == oldAction)
            .map((e) => e.key)
            .toList();
        for (final key in keysToRemove) {
          _map.remove(key);
        }
      }
      _map[event.button] = oldAction!;
      _saveAndExit();
    }
  }

  void _move(int delta) {
    final next = (_selected + delta)
        .clamp(0, GamepadManager.remappableActions.length - 1);
    if (next != _selected) setState(() => _selected = next);
  }

  void _activate() {
    if (_selected < 0 ||
        _selected >= GamepadManager.remappableActions.length) {
      return;
    }

    final action = GamepadManager.remappableActions[_selected];

    if (_listening == action) return;

    setState(() {
      _listening = action;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pressione um botão (B para cancelar)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _cancelListen() {
    setState(() => _listening = null);
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _persist() {
    final player = _selPlayer;
    if (player != null) {
      _svc.gamepad.applyOverridesFor(player.name, _map);
      final maps =
          Map<String, String>.of(_svc.settings.getControllerButtonMaps());
      final serialized = GamepadManager.serializeOverrides(_map);
      if (serialized.isEmpty) {
        maps.remove(player.name);
      } else {
        maps[player.name] = serialized;
      }
      _svc.settings.setControllerButtonMaps(maps);
    } else {
      _svc.gamepad.setButtonOverrides(_map);
      _svc.settings.setButtonMap(GamepadManager.serializeOverrides(_map));
    }
  }

  void _saveAndExit() {
    _persist();
    Navigator.of(context).pop();
  }

  void _resetToDefaults() {
    setState(() {
      _map.clear();
      _persist();
    });
  }

  String _labelForButton(GamepadButton? button) {
    if (button == null) return 'não atribuído';
    return GamepadManager.buttonLabel(button);
  }

  GamepadButton? _buttonForAction(GamepadAction action) {
    for (final entry in _map.entries) {
      if (entry.value == action) return entry.key;
    }
    return GamepadManager.defaultButtonFor(action);
  }

  NavCallbacks get _callbacks {
    final c = NavCallbacks();
    c.onUp = () => _move(-1);
    c.onDown = () => _move(1);
    c.onLeft = () => _switchPlayer(-1);
    c.onRight = () => _switchPlayer(1);
    c.onConfirm = () => _activate();
    c.onBack = () {
      if (_listening != null) {
        _cancelListen();
      } else {
        _goBack();
      }
    };
    c.onStart = () => _goBack();
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final listening = _listening;
    final player = _selPlayer;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapear Botões'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          TextButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.refresh),
            label: const Text('Padrão'),
          ),
        ],
      ),
      body: NavFocus(
        callbacks: _callbacks,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurar para:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('Padrão (todos)', 0),
                        for (var i = 0; i < _players.length; i++)
                          _chip('${_players[i].playerNumber} · ${_players[i].name}', i + 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    player != null
                        ? 'O mapeamento abaixo vale para ${player.name}. '
                            'Use ←/→ ou toque para trocar de controle.'
                        : 'Mapeamento padrao aplicado a controles sem configuracao '
                            'propria. Atalhos: Select+Start = Home, '
                            'Select+LB/RB = página.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: GamepadManager.remappableActions.length,
                itemBuilder: (context, index) {
                  final action = GamepadManager.remappableActions[index];
                  final selected = index == _selected;
                  final button = _buttonForAction(action);
                  final isListening = listening == action;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: selected
                          ? AppTheme.accent.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        enabled: !isListening,
                        selected: selected,
                        onTap: () {
                          if (!isListening) _activate();
                        },
                        title: Text(
                          GamepadManager.actionLabel(action),
                          style: TextStyle(
                            color: selected ? AppTheme.accent : AppTheme.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: isListening
                            ? const Text(
                                'Pressione um botão...',
                                style: TextStyle(color: Colors.orange),
                              )
                            : Text(
                                _labelForButton(button),
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                        trailing: isListening
                            ? const Icon(Icons.radio_button_unchecked)
                            : Icon(
                                button == null
                                    ? Icons.question_mark
                                    : Icons.gamepad,
                                color: selected
                                    ? AppTheme.accent
                                    : AppTheme.textFaint,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _sel == value ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        selected: _sel == value,
        selectedColor: AppTheme.accent,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.6),
        side: BorderSide(
          color: _sel == value ? AppTheme.accent : AppTheme.border,
        ),
        onSelected: (_) {
          if (_listening != null) return;
          setState(() {
            _sel = value;
            _reloadMap();
          });
        },
      ),
    );
  }
}
