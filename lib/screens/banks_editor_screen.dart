import 'package:flutter/material.dart';
import '../models/bank.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class BanksEditorScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const BanksEditorScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<BanksEditorScreen> createState() => _BanksEditorScreenState();
}

class _BanksEditorScreenState extends State<BanksEditorScreen> {
  late List<Bank> _banks;

  @override
  void initState() {
    super.initState();
    _banks = List<Bank>.from(widget.storage.banks);
  }

  void _save() {
    widget.storage.banks = _banks;
    widget.sync.schedulePush();
    setState(() {});
  }

  void _addBank() async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🏦');
    final balanceCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый банк'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: emojiCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(labelText: 'Эмодзи'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название'),
                    autofocus: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Начальный баланс', suffixText: '₽'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final balance = double.tryParse(balanceCtrl.text.replaceAll(',', '.')) ?? 0;
              setState(() {
                _banks.add(Bank(
                  id: 'bank_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  emoji: emojiCtrl.text.trim().isEmpty ? '🏦' : emojiCtrl.text.trim(),
                  initialBalance: balance,
                  order: _banks.length,
                ));
              });
              _save();
              Navigator.pop(ctx, true);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _editBank(Bank b) async {
    final nameCtrl = TextEditingController(text: b.name);
    final emojiCtrl = TextEditingController(text: b.emoji);
    final balanceCtrl = TextEditingController(text: b.initialBalance.toStringAsFixed(0));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать банк'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: emojiCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(labelText: 'Эмодзи'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Начальный баланс', suffixText: '₽'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final balance = double.tryParse(balanceCtrl.text.replaceAll(',', '.')) ?? 0;
              final i = _banks.indexWhere((x) => x.id == b.id);
              if (i >= 0) {
                setState(() {
                  _banks[i] = _banks[i].copyWith(
                    name: name,
                    emoji: emojiCtrl.text.trim().isEmpty ? '🏦' : emojiCtrl.text.trim(),
                    initialBalance: balance,
                  );
                });
                _save();
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _deleteBank(Bank b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить банк?'),
        content: Text('${b.emoji} ${b.name}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _banks.removeWhere((x) => x.id == b.id));
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Text('Банки'),
        actions: [
          IconButton(onPressed: _addBank, icon: const Icon(Icons.add)),
        ],
      ),
      body: _banks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Банков нет', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Нажми «+», чтобы добавить', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: _banks.map((b) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    Text(b.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text('Стартовый: ${b.initialBalance.toStringAsFixed(0)} ₽',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editBank(b),
                      icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
                    ),
                    IconButton(
                      onPressed: () => _deleteBank(b),
                      icon: Icon(Icons.delete_outline, color: cs.error),
                    ),
                  ],
                ),
              )).toList(),
            ),
    );
  }
}