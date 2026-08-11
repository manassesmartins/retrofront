import 'package:flutter/material.dart';

import '../theme.dart';

typedef ScrapeRun =
    Future<({int total, int success, int failed})> Function(
        void Function(int done, int total, String current) onProgress);

/// Dialog com barra de progresso do scraping em lote. Executa [runner] e
/// fecha sozinho ao concluir, devolvendo o resumo.
class ScrapeProgressDialog extends StatefulWidget {
  final ScrapeRun runner;
  final String title;

  const ScrapeProgressDialog({
    super.key,
    required this.runner,
    this.title = 'Baixando capas e informações',
  });

  @override
  State<ScrapeProgressDialog> createState() => _ScrapeProgressDialogState();
}

class _ScrapeProgressDialogState extends State<ScrapeProgressDialog> {
  int _done = 0;
  int _total = 0;
  int _failed = 0;
  String _current = '';
  bool _finished = false;
  int _success = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final result = await widget.runner((done, total, current) {
      if (!mounted) return;
      setState(() {
        _done = done;
        _total = total;
        _current = current;
      });
    });
    if (!mounted) return;
    setState(() {
      _done = result.total;
      _total = result.total;
      _success = result.success;
      _failed = result.failed;
      _finished = true;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 0.0 : _done / _total;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_download,
                    color: AppTheme.accent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _finished ? 'Concluído' : widget.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _finished ? 1 : progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: AppTheme.surfaceHigh,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _total == 0
                        ? 'Preparando...'
                        : '$_done de $_total jogos',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (_finished)
                    Text(
                      _failed > 0 ? '$_success ok, $_failed falhas' : '$_success ok',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _current,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textFaint,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
