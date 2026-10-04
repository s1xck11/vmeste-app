// lib/screens/partners_editor_screen.dart

import 'package:flutter/material.dart';
import '../models/partner.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class PartnersEditorScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const PartnersEditorScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<PartnersEditorScreen> createState() => _PartnersEditorScreenState();
}

class _PartnersEditorScreenState extends State<PartnersEditorScreen> {
  late List<Partner> _partners;

  @override
  void initState() {
    super.initState();
    _partners = List<Partner>.from(widget.storage.partners);
  }

  void _update(int i, Partner p) {
    setState(() => _partners[i] = p);
    widget.storage.partners = _partners;
    widget.sync.schedulePush();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(title: const Text('Партнёры и зарплата')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...List.generate(_partners.length, (i) => _buildPartner(i, cs)),
        ],
      ),
    );
  }

  Widget _buildPartner(int i, ColorScheme cs) {
    final p = _partners[i];
    final nameCtrl = TextEditingController(text: p.name);
    final rateCtrl = TextEditingController(text: p.rate.toStringAsFixed(0));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Партнёр ${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Имя'),
            onSubmitted: (v) => _update(i, Partner(id: p.id, name: v, rate: p.rate, payType: p.payType)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: rateCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Ставка', suffixText: '₽'),
            onSubmitted: (v) => _update(i, Partner(id: p.id, name: p.name, rate: double.tryParse(v) ?? 0, payType: p.payType)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: p.payType,
            decoration: const InputDecoration(labelText: 'Тип оплаты'),
            items: const [
              DropdownMenuItem(value: 'hourly', child: Text('Почасовая')),
              DropdownMenuItem(value: 'fixed', child: Text('Фиксированная')),
              DropdownMenuItem(value: 'piecework', child: Text('Сдельная')),
            ],
            onChanged: (v) => _update(i, Partner(id: p.id, name: p.name, rate: p.rate, payType: v ?? 'hourly')),
          ),
        ],
      ),
    );
  }
}