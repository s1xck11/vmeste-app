/// Модель смены.
/// 
/// Каждая смена привязана к дате (поле date) и партнёру (partner).
class Shift {
  final int id;
  String date;           // 'YYYY-MM-DD'
  String partner;        // 'partner1' | 'partner2'
  String type;           // ID типа смены
  double hours;          // количество часов
  String startTime;      // 'HH:MM'
  String endTime;        // 'HH:MM'
  String notes;
  int notification;      // минуты до начала для уведомления (0 = нет)
  double? pieceworkAmount;  // сумма для сдельной оплаты
  double? income;        // доход (для импортированных из курьера)
  String? importedFrom;  // 'courier-helper' если импортирована
  String? location;      // место работы
  int createdAt;
  int updatedAt;
  String? updatedBy;
  int? deletedAt;

  Shift({
    required this.id,
    required this.date,
    required this.partner,
    required this.type,
    this.hours = 0,
    this.startTime = '10:00',
    this.endTime = '22:00',
    this.notes = '',
    this.notification = 60,
    this.pieceworkAmount,
    this.income,
    this.importedFrom,
    this.location,
    required this.createdAt,
    int? updatedAt,
    this.updatedBy,
    this.deletedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'partner': partner,
        'type': type,
        'hours': hours,
        'startTime': startTime,
        'endTime': endTime,
        'notes': notes,
        'notification': notification,
        if (pieceworkAmount != null) 'pieceworkAmount': pieceworkAmount,
        if (income != null) 'income': income,
        if (importedFrom != null) 'importedFrom': importedFrom,
        if (location != null) 'location': location,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        if (updatedBy != null) 'updatedBy': updatedBy,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
        id: (json['id'] as num).toInt(),
        date: json['date'] as String? ?? '',
        partner: json['partner'] as String? ?? 'partner1',
        type: json['type'] as String? ?? 'day',
        hours: (json['hours'] as num?)?.toDouble() ?? 0,
        startTime: json['startTime'] as String? ?? '10:00',
        endTime: json['endTime'] as String? ?? '22:00',
        notes: json['notes'] as String? ?? '',
        notification: (json['notification'] as num?)?.toInt() ?? 60,
        pieceworkAmount: (json['pieceworkAmount'] as num?)?.toDouble(),
        income: (json['income'] as num?)?.toDouble(),
        importedFrom: json['importedFrom'] as String?,
        location: json['location'] as String?,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
        updatedBy: json['updatedBy'] as String?,
        deletedAt: (json['deletedAt'] as num?)?.toInt(),
      );

  Shift copyWith({
    String? date,
    String? partner,
    String? type,
    double? hours,
    String? startTime,
    String? endTime,
    String? notes,
    int? notification,
    double? pieceworkAmount,
    double? income,
    String? location,
    int? updatedAt,
    String? updatedBy,
    int? deletedAt,
  }) {
    return Shift(
      id: id,
      date: date ?? this.date,
      partner: partner ?? this.partner,
      type: type ?? this.type,
      hours: hours ?? this.hours,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      notification: notification ?? this.notification,
      pieceworkAmount: pieceworkAmount ?? this.pieceworkAmount,
      income: income ?? this.income,
      importedFrom: importedFrom,
      location: location ?? this.location,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}