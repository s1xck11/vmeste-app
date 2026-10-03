/// Модель списка покупок.
/// 
/// По умолчанию три списка: общий и два личных (по одному на партнёра).
class PurchaseList {
  final String id;              // 'common' | 'partner1' | 'partner2'
  String name;                  // «Общий», «Муж», «Жена»
  String emoji;                 // 🛒, 👨, 👩
  int updatedAt;                // время изменения

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

  /// Список по умолчанию
  static List<PurchaseList> defaults() => [
        PurchaseList(id: 'common', name: 'Общий', emoji: '🛒'),
        PurchaseList(id: 'partner1', name: 'Муж', emoji: '👨'),
        PurchaseList(id: 'partner2', name: 'Жена', emoji: '👩'),
      ];
}