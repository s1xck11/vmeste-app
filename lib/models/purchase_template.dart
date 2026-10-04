// lib/models/purchase_template.dart

class PurchaseTemplate {
  final String id;
  final String name;
  final String emoji;
  final List<PurchaseTemplateItem> items;
  final int updatedAt;

  PurchaseTemplate({
    required this.id,
    required this.name,
    this.emoji = '🛒',
    this.items = const [],
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'items': items.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt,
  };

  factory PurchaseTemplate.fromJson(Map<String, dynamic> json) {
    return PurchaseTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Шаблон',
      emoji: json['emoji']?.toString() ?? '🛒',
      items: (json['items'] as List?)?.map((e) => PurchaseTemplateItem.fromJson(Map<String, dynamic>.from(e))).toList() ?? [],
      updatedAt: json['updatedAt'] is int ? json['updatedAt'] : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class PurchaseTemplateItem {
  final String text;
  final String category;
  final double qty;
  final String unit;

  PurchaseTemplateItem({
    required this.text,
    this.category = 'other',
    this.qty = 1,
    this.unit = 'шт',
  });

  Map<String, dynamic> toJson() => {
    'text': text, 'category': category, 'qty': qty, 'unit': unit,
  };

  factory PurchaseTemplateItem.fromJson(Map<String, dynamic> json) {
    return PurchaseTemplateItem(
      text: json['text']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      qty: (json['qty'] as num?)?.toDouble() ?? 1,
      unit: json['unit']?.toString() ?? 'шт',
    );
  }
}