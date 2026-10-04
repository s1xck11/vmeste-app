// lib/widgets/add_task_modal.dart

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/partner.dart';

class AddTaskModal extends StatefulWidget {
  final List<TaskCategory> categories;
  final List<Partner> partners;
  final Task? initialTask;
  final Function(Task) onSave;

  const AddTaskModal({
    super.key,
    required this.categories,
    required this.partners,
    this.initialTask,
    required this.onSave,
  });

  @override
  State<AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<AddTaskModal> {
  final _nameCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String _priority = 'med';
  String _categoryId = 'home';
  String _assignee = 'any';
  String _repeat = 'none';
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      final t = widget.initialTask!;
      _nameCtrl.text = t.text;
      _commentCtrl.text = t.comment;
      _priority = t.priority;
      _categoryId = t.category;
      _assignee = t.assignee;
      _repeat = t.repeat;
      if (t.deadline.isNotEmpty) {
        _deadline = DateTime.tryParse(t.deadline);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final deadlineStr = _deadline == null
        ? ''
        : '${_deadline!.year}-${_two(_deadline!.month)}-${_two(_deadline!.day)}';

    final t = Task(
      id: widget.initialTask?.id ?? now,
      text: name,
      done: widget.initialTask?.done ?? false,
      priority: _priority,
      category: _categoryId,
      assignee: _assignee,
      deadline: deadlineStr,
      repeat: _repeat,
      comment: _commentCtrl.text.trim(),
      order: widget.initialTask?.order ?? now,
      archived: widget.initialTask?.archived ?? false,
      doneAt: widget.initialTask?.doneAt,
      createdAt: widget.initialTask?.createdAt ?? now,
      updatedAt: now,
    );
    widget.onSave(t);
    Navigator.pop(context);
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.initialTask == null ? 'Новая задача' : 'Редактировать',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameCtrl,
                autofocus: widget.initialTask == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название', hintText: 'Помыть посуду'),
              ),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Приоритет'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _chip(cs, 'low', '🟢 Низкий', _priority, (v) => setState(() => _priority = v)),
                _chip(cs, 'med', '🟡 Средний', _priority, (v) => setState(() => _priority = v)),
                _chip(cs, 'high', '🔴 Высокий', _priority, (v) => setState(() => _priority = v)),
              ]),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Категория'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((c) {
                  final sel = c.id == _categoryId;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryId = c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? cs.primaryContainer : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? cs.primary : cs.outline),
                      ),
                      child: Text(
                        '${c.emoji} ${c.label}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          color: sel ? cs.onPrimaryContainer : cs.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Ответственный'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _chip(cs, 'any', '👥 Любой', _assignee, (v) => setState(() => _assignee = v)),
                ...widget.partners.map((p) => _chip(cs, p.id, p.name, _assignee, (v) => setState(() => _assignee = v))),
              ]),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Дедлайн'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _deadline == null
                            ? 'Без дедлайна'
                            : '${_deadline!.day}.${_deadline!.month}.${_deadline!.year}',
                      ),
                    ),
                  ),
                  if (_deadline != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _deadline = null),
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              _sectionLabel(cs, 'Повторять'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _chip(cs, 'none', 'Не повторять', _repeat, (v) => setState(() => _repeat = v)),
                _chip(cs, 'daily', '🔁 Каждый день', _repeat, (v) => setState(() => _repeat = v)),
                _chip(cs, 'weekly', '🔁 Каждую неделю', _repeat, (v) => setState(() => _repeat = v)),
                _chip(cs, 'monthly', '🔁 Каждый месяц', _repeat, (v) => setState(() => _repeat = v)),
              ]),
              const SizedBox(height: 16),

              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(ColorScheme cs, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _chip(
    ColorScheme cs,
    String value,
    String label,
    String current,
    void Function(String) onTap,
  ) {
    final sel = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? cs.primaryContainer : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? cs.primary : cs.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
            color: sel ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ),
    );
  }
}