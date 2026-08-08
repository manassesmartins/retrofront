import 'package:flutter/material.dart';

import '../../models/system.dart';
import '../theme.dart';

/// Card de um sistema/console na tela inicial, com gradiente e iniciais.
class SystemTile extends StatelessWidget {
  final SystemEntry system;
  final bool selected;
  final VoidCallback onTap;

  const SystemTile({
    super.key,
    required this.system,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(system.name);
    final initials = _initials(system.fullName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppTheme.accent : Colors.white10,
          width: selected ? 2.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.first, palette.last],
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (system.gameCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${system.gameCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  system.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (system.definition.releaseYear != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${system.definition.releaseYear}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'^[A-Za-z0-9]').hasMatch(w))
        .take(3)
        .toList();
    if (words.isEmpty) return name.isNotEmpty ? name[0].toUpperCase() : '?';
    return words.map((w) => w[0].toUpperCase()).join();
  }

  List<Color> _paletteFor(String name) {
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final i = hash % AppTheme.tilePalette.length;
    final base = AppTheme.tilePalette[i];
    final end = AppTheme.tilePalette[(i + 4) % AppTheme.tilePalette.length];
    return [base.withValues(alpha: 0.92), end.withValues(alpha: 0.85)];
  }
}
