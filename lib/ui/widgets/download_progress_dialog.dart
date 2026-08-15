import 'package:flutter/material.dart';

import '../theme.dart';

typedef DownloadTask =
    Future<String?> Function(void Function(double progress) onProgress);

/// Dialog com barra de progresso de um download (buildbot libretro). Executa
/// [task] (que devolve null em caso de sucesso, ou a mensagem de erro) e fecha
/// sozinho ao concluir, devolvendo a mensagem de erro (null = sucesso).
class DownloadProgressDialog extends StatefulWidget {
  final DownloadTask task;
  final String title;
  final String itemName;

  const DownloadProgressDialog({
    super.key,
    required this.task,
    required this.title,
    required this.itemName,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double _progress = 0;
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final error = await widget.task((p) {
      if (!mounted) return;
      setState(() => _progress = p.clamp(0.0, 1.0));
    });
    if (!mounted) return;
    setState(() {
      _error = error;
      _finished = true;
    });
    if (error == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _error == null ? Icons.cloud_download : Icons.cloud_off,
                    color: _error == null ? AppTheme.accent : Colors.redAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_error == null) ...[
                LinearProgressIndicator(
                  value: _finished ? 1 : _progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: AppTheme.surfaceHigh,
                  color: AppTheme.accent,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(_progress * 100).round()}%',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  _error!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_error),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Exibe o dialog de progresso e devolve a mensagem de erro (null = sucesso).
Future<String?> showDownloadProgressDialog(
  BuildContext context, {
  required String title,
  required String itemName,
  required DownloadTask task,
}) async {
  final error = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DownloadProgressDialog(
      title: title,
      itemName: itemName,
      task: task,
    ),
  );
  return error;
}
