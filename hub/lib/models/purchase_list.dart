class PurchaseList {
  final String id;
  String name;
  String emoji;
  int updatedAt;

  PurchaseList({
    required this.id,
    required this.name,
    this.emoji = '🛒',
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'updatedAt': updatedAt,
      };

  factory PurchaseList.fromJson(Map<String, dynamic> json) => PurchaseList(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Список',
        emoji: json['emoji'] as String? ?? '🛒',
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );

  static List<PurchaseList> defaults() => [
        PurchaseList(id: 'common', name: 'Общий', emoji: '🛒'),
        PurchaseList(id: 'partner1', name: 'Муж', emoji: '👨'),
        PurchaseList(id: 'partner2', name: 'Жена', emoji: '👩'),
      ];
}