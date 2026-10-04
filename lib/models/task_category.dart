/// Категория задачи. Пример: 🏠 Дом, 💼 Работа, 🛒 Покупки
class TaskCategory {
  final String id;
  String label;
  String emoji;
  int order;
  int updatedAt;

  TaskCategory({
    required this.id,
    required this.label,
    required this.emoji,
    this.order = 0,
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'emoji': emoji,
        'order': order,
        'updatedAt': updatedAt,
      };

  factory TaskCategory.fromJson(Map<String, dynamic> json) => TaskCategory(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Категория',
        emoji: json['emoji'] as String? ?? '📦',
        order: (json['order'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );

  static List<TaskCategory> defaults() => [
        TaskCategory(id: 'home', label: 'Дом', emoji: '🏠', order: 1),
        TaskCategory(id: 'work', label: 'Работа', emoji: '💼', order: 2),
        TaskCategory(id: 'shopping', label: 'Покупки', emoji: '🛒', order: 3),
        TaskCategory(id: 'health', label: 'Здоровье', emoji: '💪', order: 4),
        TaskCategory(id: 'love', label: 'Отношения', emoji: '❤️', order: 5),
        TaskCategory(id: 'other', label: 'Прочее', emoji: '📦', order: 99),
      ];
}