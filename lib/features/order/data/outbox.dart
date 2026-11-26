import 'dart:convert';

import '../../../core/storage/local_store.dart';
import 'order_models.dart';

/// A new order that could not be sent yet. [id] is the order UUID: sending it again is safe
/// because the server returns the stored order for a known id.
class PendingOrder {
  const PendingOrder({
    required this.id,
    required this.tableId,
    required this.lines,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) => PendingOrder(
    id: json['id'] as String,
    tableId: (json['tableId'] as num).toInt(),
    lines: [
      for (final line in (json['lines'] as List<dynamic>))
        NewLine.fromJson(line as Map<String, dynamic>),
    ],
  );

  final String id;
  final int tableId;
  final List<NewLine> lines;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tableId': tableId,
    'lines': [for (final line in lines) line.toJson()],
  };
}

/// Keeps the not yet sent orders on the device.
class OutboxStore {
  OutboxStore(this._store);

  static const _key = 'bonflow.outbox';

  final LocalStore _store;

  Future<List<PendingOrder>> read() async {
    final raw = await _store.read(_key);
    if (raw == null) {
      return [];
    }
    try {
      return [
        for (final item in jsonDecode(raw) as List<dynamic>)
          PendingOrder.fromJson(item as Map<String, dynamic>),
      ];
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> write(List<PendingOrder> orders) => _store.write(
    _key,
    jsonEncode([for (final order in orders) order.toJson()]),
  );
}
