class Transaction {
  final String id;
  final String type; // 'expense' | 'income' | 'transfer'
  final double amount;
  final String categoryId;
  final String comment;
  final String nature; // 'obligatory', 'conscious', 'impulsive'
  final DateTime date;
  final DateTime createdAt;
  final int updatedAt;
  final String? updatedBy;
  final int? deletedAt;
  
  // НОВОЕ: банки
  final String? bankId;    // Откуда (для transfer) или для какого банка (income/expense)
  final String? toBankId;  // Куда (только для transfer)

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.comment = '',
    this.nature = 'conscious',
    required this.date,
    DateTime? createdAt,
    int? updatedAt,
    this.updatedBy,
    this.deletedAt,
    this.bankId,
    this.toBankId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'categoryId': categoryId,
        'comment': comment,
        'nature': nature,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
        'deletedAt': deletedAt,
        'bankId': bankId,
        'toBankId': toBankId,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId'] ?? '',
      comment: json['comment'] ?? '',
      nature: json['nature'] ?? 'conscious',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] is int
          ? json['updatedAt']
          : (json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt']).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch),
      updatedBy: json['updatedBy'],
      deletedAt: json['deletedAt'] is int
          ? json['deletedAt']
          : (json['deletedAt'] != null
              ? DateTime.parse(json['deletedAt']).millisecondsSinceEpoch
              : null),
      bankId: json['bankId'] as String?,
      toBankId: json['toBankId'] as String?,
    );
  }

  Transaction copyWith({
    String? type,
    double? amount,
    String? categoryId,
    String? comment,
    String? nature,
    DateTime? date,
    int? updatedAt,
    String? updatedBy,
    int? deletedAt,
    String? bankId,
    String? toBankId,
    bool clearBankId = false,
    bool clearToBankId = false,
  }) {
    return Transaction(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      comment: comment ?? this.comment,
      nature: nature ?? this.nature,
      date: date ?? this.date,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      bankId: clearBankId ? null : (bankId ?? this.bankId),
      toBankId: clearToBankId ? null : (toBankId ?? this.toBankId),
    );
  }
}