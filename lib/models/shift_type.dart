/// Тип смены. Пример: Дневная (12ч, зелёная), Ночная (12ч, фиолетовая)
class ShiftType {
  final String id;
  String label;
  double hours;
  String color;    // hex '#4CAF50'
  int updatedAt;

  ShiftType({
    required this.id,
    required this.label,
    this.hours = 12,
    this.color = '#4CAF50',
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hours': hours,
        'color': color,
        'updatedAt': updatedAt,
      };

  factory ShiftType.fromJson(Map<String, dynamic> json) => ShiftType(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Смена',
        hours: (json['hours'] as num?)?.toDouble() ?? 12,
        color: json['color'] as String? ?? '#4CAF50',
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );

  static List<ShiftType> defaults() => [
        ShiftType(id: 'morning', label: 'Утренняя', hours: 8, color: '#FFB74D'),
        ShiftType(id: 'day', label: 'Дневная', hours: 12, color: '#4CAF50'),
        ShiftType(id: 'night', label: 'Ночная', hours: 12, color: '#7E57C2'),
        ShiftType(id: 'dayoff', label: 'Выходной', hours: 0, color: '#90A4AE'),
        ShiftType(id: 'vacation', label: 'Отпуск', hours: 0, color: '#42A5F5'),
        ShiftType(id: 'sick', label: 'Больничный', hours: 0, color: '#EF5350'),
      ];
}