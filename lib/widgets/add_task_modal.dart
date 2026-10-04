import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/partner.dart';
import '../main.dart' show AppColors;

/// Модалка добавления/редактирования задачи.
class AddTaskModal extends StatefulWidget {
  final Task? existing;
  final String listId;
  final String defaultText;
  final List<TaskCategory> categories;
  final List<Partner> partners;
  final String? Function() currentUserIdGetter;

  const AddTaskModal({
    super.key,
    this.existing,
    required this.listId,
    this.defaultText = '',
    required this.categories,
    required this.partners,
    required this.currentUserIdGetter,
  });

  @override
  State<AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<AddTaskModal> {
  late TextEditingController _textController;
  late TextEditingController _commentController;

  String _priority = 'med';
  String _category = 'home';
  String _assignee = 'any';
  String _repeat = 'none';
  String _deadline = '';

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _textController = TextEditingController(text: t?.text ?? widget.defaultText);
    _commentController = TextEditingController(text: t?.comment ?? '');
    _priority = t?.priority ?? 'med';
    _category = t?.category ?? 'home';
    _assignee = t?.assignee ?? 'any';
    _repeat = t?.repeat ?? 'none';
    _deadline = t?.deadline ?? '';
  }

  @override
  void dispose() {
    _textController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline.isNotEmpty
        ? DateTime.tryParse(_deadline) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _deadline =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введи название')),
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final comment = _commentController.text.trim();

    final result = widget.existing != null
        ? widget.existing!.copyWith(
            text: text,
            priority: _priority,
            category: _category,
            assignee: _assignee,
            deadline: _deadline,
            repeat: _repeat,
            comment: comment,
            updatedAt: now,
            updatedBy: widget.currentUserIdGetter(),
          )
        : Task(
            id: now,
            text: text,
            priority: _priority,
            category: _category,
            assignee: _assignee,
            deadline: _deadline,
            repeat: _repeat,
            comment: comment,
            listId: widget.listId,
            createdAt: now,
            updatedAt: now,
            updatedBy: widget.currentUserIdGetter(),
          );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing == null ? 'Новая задача' : 'Редактировать',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Название
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    hintText: 'Помыть посуду',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Приоритет
                _label('Приоритет'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _priorityChip('high', '🔴 Высокий', const Color(0xFFFF3B30)),
                    _priorityChip('med', '🟡 Средний', const Color(0xFFFF9500)),
                    _priorityChip('low', '🟢 Низкий', const Color(0xFF34C759)),
                  ],
                ),
                const SizedBox(height: 20),

                // Категория
                _label('Категория'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.categories.map((c) {
                    final selected = _category == c.id;
                    return GestureDetector(
                      onTap: () => setState(() => _category = c.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accentLight
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppColors.accent
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.emoji),
                            const SizedBox(width: 4),
                            Text(c.label),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Ответственный
                _label('Ответственный'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _assigneeChip('any', '👥 Любой'),
                    for (final p in widget.partners)
                      _assigneeChip(p.id, p.name),
                  ],
                ),
                const SizedBox(height: 20),

                // Дедлайн
                _label('Дедлайн'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDeadline,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _deadline.isEmpty ? 'Не задан' : _deadline,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: _deadline.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.accent,
                        ),
                      ),
                    ),
                    if (_deadline.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() => _deadline = ''),
                        icon: const Icon(Icons.close, color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Повтор
                _label('Повтор'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _repeat,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Не повторять')),
                    DropdownMenuItem(value: 'daily', child: Text('Каждый день')),
                    DropdownMenuItem(value: 'weekly', child: Text('Каждую неделю')),
                    DropdownMenuItem(value: 'monthly', child: Text('Каждый месяц')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _repeat = v);
                  },
                ),
                const SizedBox(height: 20),

                // Комментарий
                _label('Комментарий'),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Детали, заметки...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    final selected = _priority == value;
    return GestureDetector(
      onTap: () => setState(() => _priority = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _assigneeChip(String value, String label) {
    final selected = _assignee == value;
    return GestureDetector(
      onTap: () => setState(() => _assignee = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentLight : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}