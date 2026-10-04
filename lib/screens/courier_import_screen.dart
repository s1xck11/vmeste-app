// lib/screens/courier_import_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shift.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/courier_import_service.dart';

class CourierImportScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const CourierImportScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<CourierImportScreen> createState() => _CourierImportScreenState();
}

class _CourierImportScreenState extends State<CourierImportScreen> {
  final _service = CourierImportService();
  final _controller = TextEditingController();
  List<CourierShiftPreview>? _parsed;
  String? _error;
  String _partnerId = 'partner1';
  List<Partner> _partners = [];

  @override
  void initState() {
    super.initState();
    _partners = widget.storage.partners;
    if (_partners.isNotEmpty) _partnerId = _partners[0].id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _controller.text = data!.text!;
    }
  }

  void _parse() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Вставь JSON');
      return;
    }
    final result = _service.parseJson(raw);
    setState(() {
      _parsed = result;
      _error = result == null ? 'Не удалось распарсить JSON. Проверь формат.' : null;
    });
  }

  void _import() {
    if (_parsed == null) return;
    final selected = _parsed!.where((p) => p.selected).toList();
    if (selected.isEmpty) return;

    final list = List<Shift>.from(widget.storage.shifts);
    for (final p in selected) {
      list.add(_service.toShift(p, _partnerId));
    }
    widget.storage.shifts = list;
    widget.sync.schedulePush();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Импортировано ${selected.length} смен')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Импорт из Курьера')),
      body: _parsed == null ? _buildInput(cs) : _buildPreview(cs),
    );
  }

  Widget _buildInput(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Вставь JSON-данные из courier-helper и нажми «Разобрать».',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          maxLines: 10,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            hintText: '{"from":"courier-helper","shifts":[...]}',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('Из буфера'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _controller.clear(),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Очистить'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: cs.error)),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: _parse,
          icon: const Icon(Icons.check),
          label: const Text('Разобрать'),
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final list = _parsed!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Найдено ${list.length} смен. Выбери, какие импортировать:',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Кому приписать: ', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(width: 8),
              ..._partners.map((p) {
                final sel = p.id == _partnerId;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(p.name),
                    selected: sel,
                    onSelected: (_) => setState(() => _partnerId = p.id),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final p = list[i];
              return CheckboxListTile(
                value: p.selected,
                onChanged: (v) => setState(() => p.selected = v ?? false),
                title: Text('${p.date} · ${p.startTime}–${p.endTime}'),
                subtitle: Text('${p.hours}ч · ${p.income.toStringAsFixed(0)} ₽ · ${p.type}'),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _parsed = null;
                    _error = null;
                  }),
                  child: const Text('Назад'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.download),
                  label: Text('Импортировать (${list.where((e) => e.selected).length})'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}