import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/system.dart';
import 'theme.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/nav_key_handler.dart';

/// Seleção de sistemas para os quais o app baixa capas durante o scraping.
/// Vazio = baixar capas para todos os sistemas.
class CoverSystemsView extends StatefulWidget {
  const CoverSystemsView({super.key});

  @override
  State<CoverSystemsView> createState() => _CoverSystemsViewState();
}

class _CoverSystemsViewState extends State<CoverSystemsView> {
  AppServices get _svc => AppScope.of(context);

  List<SystemDefinition> _systems = [];
  Set<String> _selected = {};
  bool _loading = true;
  int _selectedIndex = 0;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
    _load();
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final systems = await _svc.systems.load();
    final current = _svc.settings
        .getCoverSystems()
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (!mounted) return;
    setState(() {
      _systems = systems;
      _selected = current;
      _loading = false;
    });
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) return;

    switch (action) {
      case GamepadAction.up:
        _move(-1);
      case GamepadAction.down:
        _move(1);
      case GamepadAction.pageUp:
        _move(-6);
      case GamepadAction.pageDown:
        _move(6);
      case GamepadAction.confirm:
        _toggleSelected();
      case GamepadAction.back:
        _saveAndExit();
      case GamepadAction.start:
      case GamepadAction.home:
        _saveAndExit();
      case GamepadAction.left:
      case GamepadAction.right:
      case GamepadAction.select:
        break;
    }
  }

  void _move(int delta) {
    if (_systems.isEmpty) return;
    final next = (_selectedIndex + delta).clamp(0, _systems.length - 1);
    if (next != _selectedIndex) setState(() => _selectedIndex = next);
  }

  void _toggleSelected() {
    if (_systems.isEmpty) return;
    final name = _systems[_selectedIndex].name.toLowerCase();
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  Future<void> _saveAndExit() async {
    await _svc.settings.setCoverSystems(_selected.join(','));
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _move(-1);
    }
    ..onDown = () {
      _move(1);
    }
    ..onPageUp = () {
      _move(-6);
    }
    ..onPageDown = () {
      _move(6);
    }
    ..onConfirm = _toggleSelected
    ..onBack = () {
      _saveAndExit();
    }
    ..onStart = () {
      _saveAndExit();
    }
    ..onHome = () {
      _saveAndExit();
    };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistemas para capas'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _selected.clear());
            },
            child: const Text('Nenhum'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selected = _systems.map((s) => s.name.toLowerCase()).toSet();
              });
            },
            child: const Text('Todos'),
          ),
        ],
      ),
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(color: AppTheme.accent, darken: 0.62),
            if (_loading)
              Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _systems.length,
                itemBuilder: (context, index) {
                  final system = _systems[index];
                  final selected = index == _selectedIndex;
                  final checked =
                      _selected.contains(system.name.toLowerCase());
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Material(
                      color: selected
                          ? AppTheme.accent.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        selected: selected,
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          _toggleSelected();
                        },
                        leading: Icon(
                          checked
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: checked ? AppTheme.accent : AppTheme.textFaint,
                        ),
                        title: Text(
                          system.fullName,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textPrimary,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          system.name,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
