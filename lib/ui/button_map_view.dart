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
  StreamSubscription<GamepadButton>? _rawSub;
  int _selected = 0;
  bool _depsReady = false;

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
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    _rawSub?.cancel();
    super.dispose();
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

  void _onRawButton(GamepadButton button) {
    if (_listening == null) return;
    if (!_map.containsKey(button)) {
      final oldAction = _listening;
      if (oldAction != null) {
        final entriesToRemove = _map.entries
            .where((e) => e.value == oldAction)
            .map((e) => e.key)
            .toList();
        for (final key in entriesToRemove) {
          _map.remove(key);
        }
      }
      _map[button] = oldAction!;
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

  void _saveAndExit() {
    _svc.gamepad.setButtonOverrides(_map);
    _svc.settings.setButtonMap(_svc.gamepad.serializeButtonMap());
    Navigator.of(context).pop();
  }

  void _resetToDefaults() {
    setState(() {
      _map.clear();
      _svc.gamepad.setButtonOverrides({});
      _svc.settings.setButtonMap('');
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
                                style: const TextStyle(color: Colors.white70),
                              ),
                        trailing: isListening
                            ? const Icon(Icons.radio_button_unchecked)
                            : Icon(
                                button == null
                                    ? Icons.question_mark
                                    : Icons.gamepad,
                                color: selected
                                    ? AppTheme.accent
                                    : Colors.white38,
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
}