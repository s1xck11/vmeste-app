/// Модель задачи.
/// 
/// Задачи бывают общие (listId='common') и личные (listId='partner1'/'partner2').
class Task {
  final int id;
  String text;
  bool done;
  String priority;
  String category;
  String assignee;
  String listId;
  String deadline;
  String repeat;
  String comment;
  int order;
  bool archived;
  int? doneAt;
  int createdAt;
  int updatedAt;
  String? updatedBy;
  int? deletedAt;

  // НОВОЕ: кто создал / взял / выполнил
  String? createdBy;
  String? createdByName;
  int? createdByAt;
  String? takenBy;
  String? takenByName;
  int? takenByAt;
  String? doneBy;
  String? doneByName;

  Task({
    required this.id,
    required this.text,
    this.done = false,
    this.priority = 'med',
    this.category = 'home',
    this.assignee = 'any',
    this.listId = 'common',
    this.deadline = '',
    this.repeat = 'none',
    this.comment = '',
    this.order = 0,
    this.archived = false,
    this.doneAt,
    required this.createdAt,
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
        'priority': priority,
        'category': category,
        'assignee': assignee,
        'listId': listId,
        'deadline': deadline,
        'repeat': repeat,
        'comment': comment,
        'order': order,
        'archived': archived,
        if (doneAt != null) 'doneAt': doneAt,
        'createdAt': createdAt,
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

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: (json['id'] as num).toInt(),
        text: json['text'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        priority: json['priority'] as String? ?? 'med',
        category: json['category'] as String? ?? 'home',
        assignee: json['assignee'] as String? ?? 'any',
        listId: json['listId'] as String? ?? 'common',
        deadline: json['deadline'] as String? ?? '',
        repeat: json['repeat'] as String? ?? 'none',
        comment: json['comment'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        archived: json['archived'] as bool? ?? false,
        doneAt: (json['doneAt'] as num?)?.toInt(),
        createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
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

  Task copyWith({
    String? text,
    bool? done,
    String? priority,
    String? category,
    String? assignee,
    String? listId,
    String? deadline,
    String? repeat,
    String? comment,
    int? order,
    bool? archived,
    int? doneAt,
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
    return Task(
      id: id,
      text: text ?? this.text,
      done: done ?? this.done,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      assignee: assignee ?? this.assignee,
      listId: listId ?? this.listId,
      deadline: deadline ?? this.deadline,
      repeat: repeat ?? this.repeat,
      comment: comment ?? this.comment,
      order: order ?? this.order,
      archived: archived ?? this.archived,
      doneAt: doneAt ?? this.doneAt,
      createdAt: createdAt,
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
}