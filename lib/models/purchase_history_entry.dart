// lib/models/purchase_history_entry.dart

class PurchaseHistoryEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String listId;
  final List<PurchaseHistoryItem> items;

  PurchaseHistoryEntry({
    required this.id,
    required this.date,
    required this.listId,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'listId': listId,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory PurchaseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PurchaseHistoryEntry(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      listId: json['listId']?.toString() ?? 'default',
      items: (json['items'] as List?)?.map((e) => PurchaseHistoryItem.fromJson(Map<String, dynamic>.from(e))).toList() ?? [],
    );
  }
}

class PurchaseHistoryItem {
  final String text;
  final String category;
  final double qty;
  final String unit;
  final double price;

  PurchaseHistoryItem({
    required this.text,
    this.category = 'other',
    this.qty = 1,
    this.unit = 'шт',
    this.price = 0,
  });

  Map<String, dynamic> toJson() => {
    'text': text, 'category': category, 'qty': qty, 'unit': unit, 'price': price,
  };

  factory PurchaseHistoryItem.fromJson(Map<String, dynamic> json) {
    return PurchaseHistoryItem(
      text: json['text']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      qty: (json['qty'] as num?)?.toDouble() ?? 1,
      unit: json['unit']?.toString() ?? 'шт',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}