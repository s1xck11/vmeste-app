class RecurringPayment {
  final String id;
  String name;
  double amount;
  String type; // 'expense' | 'income'
  String categoryId;
  String? bankId;
  int dayOfMonth; // 1-31
  bool enabled;
  DateTime? lastPaidAt;
  int createdAt;
  int updatedAt;

  RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    this.type = 'expense',
    this.categoryId = 'cat_other_expense',
    this.bankId,
    this.dayOfMonth = 1,
    this.enabled = true,
    this.lastPaidAt,
    required this.createdAt,
    int? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'type': type,
        'categoryId': categoryId,
        'bankId': bankId,
        'dayOfMonth': dayOfMonth,
        'enabled': enabled,
        'lastPaidAt': lastPaidAt?.toIso8601String(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory RecurringPayment.fromJson(Map<String, dynamic> json) => RecurringPayment(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Платёж',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        type: json['type'] as String? ?? 'expense',
        categoryId: json['categoryId'] as String? ?? 'cat_other_expense',
        bankId: json['bankId'] as String?,
        dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
        enabled: json['enabled'] as bool? ?? true,
        lastPaidAt: json['lastPaidAt'] != null ? DateTime.tryParse(json['lastPaidAt']) : null,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );

  RecurringPayment copyWith({
    String? name,
    double? amount,
    String? type,
    String? categoryId,
    String? bankId,
    int? dayOfMonth,
    bool? enabled,
    DateTime? lastPaidAt,
    int? updatedAt,
    bool clearLastPaid = false,
  }) {
    return RecurringPayment(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      bankId: bankId ?? this.bankId,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      enabled: enabled ?? this.enabled,
      lastPaidAt: clearLastPaid ? null : (lastPaidAt ?? this.lastPaidAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}