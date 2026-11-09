// lib/widgets/update_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// Диалог обновления с визуальным прогрессом скачивания.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final UpdateService service;

  const UpdateDialog._({required this.info, required this.service});

  static void show(BuildContext context, UpdateInfo info, UpdateService service) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog._(info: info, service: service),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  String _status = 'Подготовка...';
  int _received = 0;
  int _total = 0;
  double _speed = 0;
  String _phase = 'downloading'; // downloading | ready | error
  bool _cancelled = false;
  File? _file;
  int _lastBytes = 0;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _phase = 'downloading';
      _status = 'Скачивание...';
      _cancelled = false;
      _lastBytes = 0;
      _lastTick = DateTime.now();
    });

    final f = await widget.service.downloadApk(
      widget.info,
      isCancelled: () => _cancelled,
      onStatus: (s) {
        if (mounted) setState(() => _status = s);
      },
      onProgress: (r, t) {
        if (!mounted) return;
        final now = DateTime.now();
        final dt = now.difference(_lastTick).inMilliseconds;
        if (dt >= 500) {
          _speed = (r - _lastBytes) * 1000.0 / dt;
          _lastBytes = r;
          _lastTick = now;
        }
        setState(() {
          _received = r;
          _total = t;
        });
      },
    );

    if (!mounted || _cancelled) return;
    if (f == null) {
      setState(() {
        _phase = 'error';
        _status = 'Не удалось скачать пакет';
      });
    } else {
      setState(() {
        _phase = 'ready';
        _status = 'Загружено, готово к установке';
        _file = f;
      });
    }
  }

  String _mb(num b) => (b / 1048576).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : 0.0;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Обновление до ${widget.info.version}',
        style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.info.body.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 110),
              child: SingleChildScrollView(
                child: Text(
                  widget.info.body,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _phase == 'ready' ? 1 : progress,
              minHeight: 8,
              backgroundColor: cs.surfaceVariant,
              color: _phase == 'error' ? cs.error : cs.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _phase == 'ready' ? '100%' : '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface),
              ),
              Text(
                '${_mb(_received)} / ${_mb(_total)} MB',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _phase == 'downloading'
                ? '$_status · ${_mb(_speed)} MB/s'
                : _status,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        if (_phase == 'downloading')
          TextButton(
            onPressed: () {
              _cancelled = true;
              Navigator.pop(context);
            },
            child: const Text('Отмена'),
          ),
        if (_phase == 'error') ...[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
          ElevatedButton(onPressed: _start, child: const Text('Повторить')),
        ],
        if (_phase == 'ready')
          ElevatedButton.icon(
            onPressed: () async {
              final f = _file;
              if (f == null) return;
              Navigator.pop(context);
              await widget.service.installApk(f);
            },
            icon: const Icon(Icons.install_mobile, size: 18),
            label: const Text('Установить'),
          ),
      ],
    );
  }
}