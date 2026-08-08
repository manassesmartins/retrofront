import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_dirs.dart';
import '../core/app_scope.dart';

/// Configuracoes do aplicativo: pasta de ROMs, chaves de scraping,
/// emulador, tema e gamepad.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  AppServices get _svc => AppScope.of(context);

  final TextEditingController _romsPath = TextEditingController();
  final TextEditingController _tgdbKey = TextEditingController();
  final TextEditingController _retroArchPath = TextEditingController();

  bool _darkMode = true;
  int _gridColumns = 0;
  int _gamepadRepeat = 300;
  bool _loading = true;
  String _defaultRoms = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _romsPath.dispose();
    _tgdbKey.dispose();
    _retroArchPath.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = _svc.settings;
    final defaultRoms = (await AppDirs.romsRoot()).path;

    if (!mounted) return;
    setState(() {
      _defaultRoms = defaultRoms;
      _romsPath.text = settings.getRomsPath() ?? '';
      _tgdbKey.text = settings.getTheGamesDbKey() ?? '';
      _retroArchPath.text = settings.getRetroArchPath() ?? '';
      _darkMode = settings.getDarkMode();
      _gridColumns = settings.getGridColumns();
      _gamepadRepeat = settings.getGamepadRepeatMs();
      _loading = false;
    });
  }

  Future<void> _pickFolder(TextEditingController controller) async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) {
      setState(() => controller.text = path);
    }
  }

  Future<void> _pickRetroArch() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe', 'sh', 'bin'],
    );
    final path = result?.files.single.path;
    if (path != null) {
      setState(() => _retroArchPath.text = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white70,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            icon: Icons.folder,
            title: 'Biblioteca',
            children: [
              TextField(
                controller: _romsPath,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Pasta de ROMs',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: _defaultRoms,
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open),
                    color: Colors.white54,
                    onPressed: () => _pickFolder(_romsPath),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crie uma subpasta por console (nes, snes, psx, gba...). '
                'Se vazio, usa a pasta padrão da plataforma.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            icon: Icons.cloud_download,
            title: 'Internet / Scraping',
            children: [
              TextField(
                controller: _tgdbKey,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Chave TheGamesDB (opcional)',
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: 'Deixe vazio para usar apenas capas (libretro-thumbnails)',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sem chave: capas via libretro-thumbnails (grátis). '
                'Com chave: também descrição, gênero, ano e avaliação.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!AppDirs.isAndroid && !AppDirs.isIOS)
            _section(
              icon: Icons.memory,
              title: 'Emulador (Desktop)',
              children: [
                TextField(
                  controller: _retroArchPath,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Caminho do RetroArch',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: 'Auto-detectado no PATH',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      color: Colors.white54,
                      onPressed: _pickRetroArch,
                    ),
                  ),
                ),
              ],
            ),
          if (!AppDirs.isAndroid && !AppDirs.isIOS) const SizedBox(height: 16),
          _section(
            icon: Icons.palette,
            title: 'Aparência',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Tema escuro',
                  style: TextStyle(color: Colors.white),
                ),
                value: _darkMode,
                activeThumbColor: const Color(0xFF8B5CF6),
                onChanged: (v) {
                  setState(() => _darkMode = v);
                  _svc.settings.setDarkMode(v);
                  _svc.darkMode.value = v;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Densidade da grade de jogos',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Auto')),
                      ButtonSegment(value: 4, label: Text('4')),
                      ButtonSegment(value: 6, label: Text('6')),
                      ButtonSegment(value: 8, label: Text('8')),
                    ],
                    selected: {_gridColumns},
                    onSelectionChanged: (s) {
                      setState(() => _gridColumns = s.first);
                      _svc.settings.setGridColumns(s.first);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            icon: Icons.sports_esports,
            title: 'Controles',
            children: [
              Text(
                'A / Cross = confirmar  •  B / Círculo = voltar\n'
                'D-pad / Analógico = navegar  •  Start = menu\n'
                'LB / RB = trocar de página',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Repetição da navegação',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    '${_gamepadRepeat}ms',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
              Slider(
                value: _gamepadRepeat.toDouble(),
                min: 100,
                max: 600,
                divisions: 10,
                activeColor: const Color(0xFF8B5CF6),
                onChanged: (v) {
                  setState(() => _gamepadRepeat = v.round());
                  _svc.settings.setGamepadRepeatMs(v.round());
                  _svc.gamepad.setRepeatInterval(
                    Duration(milliseconds: v.round()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: () {
                _svc.settings.setRomsPath(_romsPath.text);
                _svc.settings.setTheGamesDbKey(_tgdbKey.text);
                _svc.settings.setRetroArchPath(_retroArchPath.text);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'RetroFront 0.1.0 — inspirado na arquitetura do ES-DE',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171C26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
