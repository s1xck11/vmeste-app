/// Модель категории покупки.
/// 
/// Пример: 🥛 Молочное, 🥩 Мясо/рыба, 🥦 Овощи/фрукты
class PurchaseCategory {
  final String id;              // 'dairy', 'meat', 'veggies', ...
  String label;                 // «Молочное»
  String emoji;                 // 🥛
  int order;                    // порядок отображения
  int updatedAt;

  PurchaseCategory({
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

  factory PurchaseCategory.fromJson(Map<String, dynamic> json) => PurchaseCategory(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Категория',
        emoji: json['emoji'] as String? ?? '📦',
        order: (json['order'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );

  /// Категории по умолчанию
  static List<PurchaseCategory> defaults() => [
        PurchaseCategory(id: 'dairy', label: 'Молочное', emoji: '🥛', order: 1),
        PurchaseCategory(id: 'meat', label: 'Мясо/рыба', emoji: '🥩', order: 2),
        PurchaseCategory(id: 'veggies', label: 'Овощи/фрукты', emoji: '🥦', order: 3),
        PurchaseCategory(id: 'bread', label: 'Хлеб', emoji: '🍞', order: 4),
        PurchaseCategory(id: 'sweets', label: 'Сладкое', emoji: '🍫', order: 5),
        PurchaseCategory(id: 'drinks', label: 'Напитки', emoji: '🥤', order: 6),
        PurchaseCategory(id: 'household', label: 'Бытовая химия', emoji: '🧴', order: 7),
        PurchaseCategory(id: 'pet', label: 'Питомцы', emoji: '🐱', order: 8),
        PurchaseCategory(id: 'other', label: 'Прочее', emoji: '📦', order: 99),
      ];
}