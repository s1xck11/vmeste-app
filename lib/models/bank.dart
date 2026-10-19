class Bank {
  final String id;
  String name;
  String emoji;
  int colorValue;
  double initialBalance; // Стартовый баланс
  int order;
  int updatedAt;

  Bank({
    required this.id,
    required this.name,
    this.emoji = '🏦',
    this.colorValue = 0xFF5856D6,
    this.initialBalance = 0,
    this.order = 0,
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorValue': colorValue,
        'initialBalance': initialBalance,
        'order': order,
        'updatedAt': updatedAt,
      };

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Банк',
        emoji: json['emoji'] as String? ?? '🏦',
        colorValue: json['colorValue'] as int? ?? 0xFF5856D6,
        initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0,
        order: (json['order'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );

  Bank copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    double? initialBalance,
    int? order,
    int? updatedAt,
  }) {
    return Bank(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      initialBalance: initialBalance ?? this.initialBalance,
      order: order ?? this.order,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<Bank> defaults() => [
        Bank(id: 'sber', name: 'Сбербанк', emoji: '🟢', colorValue: 0xFF21A038, order: 1),
        Bank(id: 'tinkoff', name: 'Тинькофф', emoji: '🟡', colorValue: 0xFFFFDD2D, order: 2),
        Bank(id: 'cash', name: 'Наличные', emoji: '💵', colorValue: 0xFF34C759, order: 3),
      ];
}