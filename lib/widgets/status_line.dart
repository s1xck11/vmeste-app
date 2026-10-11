// lib/widgets/status_line.dart

import 'package:flutter/material.dart';

/// Компактная строка статуса: "Выполняет Серёжа · 5м".
/// 
/// Приоритет отображения:
/// 1. Если done → "Выполнил X · Y"
/// 2. Если taken → "Выполняет X · Y"
/// 3. Если created → "Создано X · Y"
/// 4. Иначе → ничего
class StatusLine extends StatelessWidget {
  final bool done;
  final String? doneByName;
  final int? doneAt;

  final String? takenByName;
  final int? takenByAt;

  final String? createdByName;
  final int? createdByAt;

  const StatusLine({
    super.key,
    required this.done,
    this.doneByName,
    this.doneAt,
    this.takenByName,
    this.takenByAt,
    this.createdByName,
    this.createdByAt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String? text;
    Color color = cs.onSurfaceVariant;

    if (done && doneByName != null) {
      text = 'Выполнил $doneByName${_time(doneAt)}';
      color = cs.tertiary;
    } else if (takenByName != null) {
      text = 'Выполняет $takenByName${_time(takenByAt)}';
      color = cs.primary;
    } else if (createdByName != null) {
      text = 'Создано $createdByName${_time(createdByAt)}';
    }

    if (text == null) return const SizedBox.shrink();

    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// " · 5м", " · 2ч", " · вчера", " · 11 окт"
  String _time(int? ms) {
    if (ms == null) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(t);

    if (diff.inMinutes < 1) return '';
    if (diff.inMinutes < 60) return ' · ${diff.inMinutes}м';
    if (diff.inHours < 24) return ' · ${diff.inHours}ч';
    if (diff.inDays == 1) return ' · вчера';
    if (diff.inDays < 7) return ' · ${diff.inDays}д';

    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return ' · ${t.day} ${months[t.month - 1]}';
  }
}