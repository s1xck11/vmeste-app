import 'package:flutter/material.dart';

class BudgetCategory {
  final String id;
  final String name;
  final String type;
  final String emoji;
  final int colorValue;
  final DateTime createdAt;
  final int updatedAt;
  final String? updatedBy;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.type,
    this.emoji = '📦',
    this.colorValue = 0xFF9E9E9E,
    DateTime? createdAt,
    int? updatedAt,
    this.updatedBy,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'emoji': emoji,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Без названия',
      type: json['type'] ?? 'expense',
      emoji: json['emoji'] ?? '📦',
      colorValue: json['colorValue'] ?? 0xFF9E9E9E,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] is int
          ? json['updatedAt']
          : (json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt']).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch),
      updatedBy: json['updatedBy'],
    );
  }
}