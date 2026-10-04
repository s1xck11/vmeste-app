/// Настройки партнёра: имя, ставка, тип оплаты.
/// 
/// В приложении два партнёра: partner1 и partner2.
class Partner {
  final String id;      // 'partner1' | 'partner2'
  String name;          // 'Муж' | 'Жена' — редактируется
  double rate;          // ставка: ₽/час для почасовой, ₽/смена для фиксированной
  String payType;       // 'hourly' | 'fixed' | 'piecework'
  int updatedAt;

  Partner({
    required this.id,
    this.name = 'Партнёр',
    this.rate = 300,
    this.payType = 'hourly',
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rate': rate,
        'payType': payType,
        'updatedAt': updatedAt,
      };

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Партнёр',
        rate: (json['rate'] as num?)?.toDouble() ?? 300,
        payType: json['payType'] as String? ?? 'hourly',
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );

  static List<Partner> defaults() => [
        Partner(id: 'partner1', name: 'Муж', rate: 300, payType: 'hourly'),
        Partner(id: 'partner2', name: 'Жена', rate: 250, payType: 'hourly'),
      ];
}