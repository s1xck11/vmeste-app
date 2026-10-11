/// Модель покупки.
/// 
/// Один товар в списке покупок. Может быть общим или личным (зависит от listId).
class Purchase {
  final int id;
  String text;
  bool done;
  bool missing;
  String category;
  double qty;
  String unit;
  double price;
  String listId;
  int order;
  int createdAt;
  int? boughtAt;
  int updatedAt;
  String? updatedBy;
  int? deletedAt;

  // НОВОЕ: кто создал / взял / купил
  String? createdBy;      // 'partner1' | 'partner2'
  String? createdByName;  // 'Серёжа' | 'Настя'
  int? createdByAt;       // когда создал (ms)
  String? takenBy;
  String? takenByName;
  int? takenByAt;         // когда взял (ms)
  String? doneBy;
  String? doneByName;
  // doneAt — уже есть (boughtAt), используем как "когда купил"

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
    this.createdBy,
    this.createdByName,
    this.createdByAt,
    this.takenBy,
    this.takenByName,
    this.takenByAt,
    this.doneBy,
    this.doneByName,
  }) : updatedAt = updatedAt ?? createdAt;

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
        if (createdBy != null) 'createdBy': createdBy,
        if (createdByName != null) 'createdByName': createdByName,
        if (createdByAt != null) 'createdByAt': createdByAt,
        if (takenBy != null) 'takenBy': takenBy,
        if (takenByName != null) 'takenByName': takenByName,
        if (takenByAt != null) 'takenByAt': takenByAt,
        if (doneBy != null) 'doneBy': doneBy,
        if (doneByName != null) 'doneByName': doneByName,
      };

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
        createdBy: json['createdBy'] as String?,
        createdByName: json['createdByName'] as String?,
        createdByAt: (json['createdByAt'] as num?)?.toInt(),
        takenBy: json['takenBy'] as String?,
        takenByName: json['takenByName'] as String?,
        takenByAt: (json['takenByAt'] as num?)?.toInt(),
        doneBy: json['doneBy'] as String?,
        doneByName: json['doneByName'] as String?,
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
    String? createdBy,
    String? createdByName,
    int? createdByAt,
    String? takenBy,
    String? takenByName,
    int? takenByAt,
    String? doneBy,
    String? doneByName,
    bool clearTakenBy = false,
    bool clearDoneBy = false,
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
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdByAt: createdByAt ?? this.createdByAt,
      takenBy: clearTakenBy ? null : (takenBy ?? this.takenBy),
      takenByName: clearTakenBy ? null : (takenByName ?? this.takenByName),
      takenByAt: clearTakenBy ? null : (takenByAt ?? this.takenByAt),
      doneBy: clearDoneBy ? null : (doneBy ?? this.doneBy),
      doneByName: clearDoneBy ? null : (doneByName ?? this.doneByName),
    );
  }

  double get total => price * qty;
}