import 'package:flutter/material.dart';
import '../models/recurring_payment.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/add_recurring_modal.dart';

class RecurringPaymentsScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService sync;

  const RecurringPaymentsScreen({
    super.key,
    required this.storage,
    required this.sync,
  });

  @override
  State<RecurringPaymentsScreen> createState() => _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen> {
  List<RecurringPayment> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.sync.addListener(_load);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_load);
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    setState(() => _payments = widget.storage.recurringPayments);
  }

  void _save(List<RecurringPayment> list) {
    widget.storage.recurringPayments = list;
    widget.sync.schedulePush();
    _load();
  }

  void _add() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRecurringModal(
        categories: widget.storage.budgetCategories,
        banks: widget.storage.banks,
        onSave: (p) {
          final list = List<RecurringPayment>.from(_payments)..add(p);
          _save(list);
        },
      ),
    );
  }

  void _edit(RecurringPayment p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRecurringModal(
        categories: widget.storage.budgetCategories,
        banks: widget.storage.banks,
        initialPayment: p,
        onSave: (updated) {
          final list = List<RecurringPayment>.from(_payments);
          final i = list.indexWhere((e) => e.id == updated.id);
          if (i >= 0) list[i] = updated;
          _save(list);
        },
      ),
    );
  }

  void _toggle(RecurringPayment p) {
    final list = List<RecurringPayment>.from(_payments);
    final i = list.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      list[i] = p.copyWith(enabled: !p.enabled, updatedAt: DateTime.now().millisecondsSinceEpoch);
      _save(list);
    }
  }

  void _delete(RecurringPayment p) {
    final list = List<RecurringPayment>.from(_payments)..removeWhere((e) => e.id == p.id);
    _save(list);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: const Text('Регулярные платежи'),
        actions: [
          IconButton(onPressed: _add, icon: const Icon(Icons.add)),
        ],
      ),
      body: _payments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Нет регулярных платежей', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Нажми «+», чтобы создать', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: _payments.map((p) {
                final bank = p.bankId != null ? widget.storage.banks.firstWhere((b) => b.id == p.bankId, orElse: () => widget.storage.banks.first) : null;
                final cat = widget.storage.budgetCategories.firstWhere((c) => c.id == p.categoryId, orElse: () => widget.storage.budgetCategories.first);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        p.enabled ? Icons.check_circle : Icons.pause_circle_outline,
                        color: p.enabled ? cs.tertiary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                            const SizedBox(height: 4),
                            Text(
                              '${p.amount.toStringAsFixed(0)} ₽ · ${p.dayOfMonth}-го числа${bank != null ? " · ${bank.name}" : ""}',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: p.enabled,
                        onChanged: (_) => _toggle(p),
                      ),
                      IconButton(
                        onPressed: () => _edit(p),
                        icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
                      ),
                      IconButton(
                        onPressed: () => _delete(p),
                        icon: Icon(Icons.delete_outline, color: cs.error),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}