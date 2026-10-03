/// Модель покупки.
/// 
/// Один товар в списке покупок. Может быть общим или личным (зависит от listId).
class Purchase {
  final int id;                 // уникальный ID (timestamp)
  String text;                  // название товара
  bool done;                    // куплено
  bool missing;                 // нет в наличии
  String category;              // ID категории (dairy, meat, ...)
  double qty;                   // количество
  String unit;                  // единица измерения (шт, кг, л, ...)
  double price;                 // цена за единицу
  String listId;                // 'common' | 'partner1' | 'partner2'
  int order;                    // порядок в списке
  int createdAt;                // время создания (ms)
  int? boughtAt;                // время покупки (ms)
  int updatedAt;                // время последнего изменения (ms)
  String? updatedBy;            // UID того, кто менял
  int? deletedAt;               // если удалён (soft-delete)

  Purchase({
    required this.id,
    required this.text,
    this.done = false,
    this.missing = false,
    this.category = 'other',
    this.qty = 1,
    this.unit = 'шт',
    this.price = 0,
    this.listId = 'common',
    this.order = 0,
    required this.createdAt,
    this.boughtAt,
    int? updatedAt,
    this.updatedBy,
    this.deletedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  /// Сериализация в JSON для Supabase
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'done': done,
        'missing': missing,
        'category': category,
        'qty': qty,
        'unit': unit,
        'price': price,
        'listId': listId,
        'order': order,
        'createdAt': createdAt,
        if (boughtAt != null) 'boughtAt': boughtAt,
        'updatedAt': updatedAt,
        if (updatedBy != null) 'updatedBy': updatedBy,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  /// Десериализация из JSON
  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: (json['id'] as num).toInt(),
        text: json['text'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        missing: json['missing'] as bool? ?? false,
        category: json['category'] as String? ?? 'other',
        qty: (json['qty'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? 'шт',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        listId: json['listId'] as String? ?? 'common',
        order: (json['order'] as num?)?.toInt() ?? 0,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        boughtAt: (json['boughtAt'] as num?)?.toInt(),
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
        updatedBy: json['updatedBy'] as String?,
        deletedAt: (json['deletedAt'] as num?)?.toInt(),
      );

  Purchase copyWith({
    String? text,
    bool? done,
    bool? missing,
    String? category,
    double? qty,
    String? unit,
    double? price,
    String? listId,
    int? order,
    int? boughtAt,
    int? updatedAt,
    String? updatedBy,
    int? deletedAt,
  }) {
    return Purchase(
      id: id,
      text: text ?? this.text,
      done: done ?? this.done,
      missing: missing ?? this.missing,
      category: category ?? this.category,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      listId: listId ?? this.listId,
      order: order ?? this.order,
      createdAt: createdAt,
      boughtAt: boughtAt ?? this.boughtAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Общая сумма (цена × количество)
  double get total => price * qty;
}