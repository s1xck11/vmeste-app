// lib/models/transaction.dart

class Transaction {
  final String id;
  final String type; // 'expense' или 'income'
  final double amount;
  final String categoryId;
  final String comment;
  final String nature; // 'obligatory', 'conscious', 'impulsive'
  final DateTime date;
  final DateTime createdAt;
  final int updatedAt; // миллисекунды
  final String? updatedBy;
  final int? deletedAt; // миллисекунды, если удалено

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
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId'] ?? '',
      comment: json['comment'] ?? '',
      nature: json['nature'] ?? 'conscious',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
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
    );
  }
}