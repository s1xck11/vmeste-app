// lib/models/transaction.dart

class Transaction {
  final String id;
  final String type; // 'expense' или 'income'
  final double amount;
  final String categoryId; // Ссылка на BudgetCategory
  final String comment; // Например, "Пятёрочка"
  final String nature; // 'obligatory', 'conscious', 'impulsive'
  final DateTime date; // Дата совершения
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.comment = '',
    this.nature = 'conscious',
    required this.date,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.updatedBy,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'categoryId': categoryId,
        'comment': comment,
        'nature': nature,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'updatedBy': updatedBy,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '',
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
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      updatedBy: json['updatedBy'],
    );
  }

  Transaction copyWith({
    String? type,
    double? amount,
    String? categoryId,
    String? comment,
    String? nature,
    DateTime? date,
    DateTime? updatedAt,
    String? updatedBy,
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
    );
  }
}