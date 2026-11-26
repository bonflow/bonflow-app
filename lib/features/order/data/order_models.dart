enum TicketKind { newOrder, addition, storno }

enum TicketStatus { newTicket, inProgress, done }

TicketKind _kind(String value) => switch (value) {
  'ADDITION' => TicketKind.addition,
  'STORNO' => TicketKind.storno,
  _ => TicketKind.newOrder,
};

TicketStatus _status(String value) => switch (value) {
  'IN_PROGRESS' => TicketStatus.inProgress,
  'DONE' => TicketStatus.done,
  _ => TicketStatus.newTicket,
};

/// One line the waiter wants to send (not yet part of an order).
class NewLine {
  const NewLine({
    required this.articleId,
    required this.quantity,
    this.note,
    this.course,
    this.modifierIds = const [],
  });

  final int articleId;
  final int quantity;
  final String? note;
  final int? course;
  final List<int> modifierIds;

  Map<String, dynamic> toJson() => {
    'articleId': articleId,
    'quantity': quantity,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    if (course != null) 'course': course,
    'modifierIds': modifierIds,
  };
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.articleId,
    required this.quantity,
    required this.submissionNo,
    required this.cancelled,
    required this.modifierIds,
    this.note,
    this.course,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: (json['id'] as num).toInt(),
    articleId: (json['articleId'] as num).toInt(),
    quantity: (json['quantity'] as num).toInt(),
    note: json['note'] as String?,
    course: (json['course'] as num?)?.toInt(),
    submissionNo: (json['submissionNo'] as num).toInt(),
    cancelled: json['status'] == 'CANCELLED',
    modifierIds: [
      for (final id in (json['modifierIds'] as List<dynamic>? ?? <dynamic>[]))
        (id as num).toInt(),
    ],
  );

  final int id;
  final int articleId;
  final int quantity;
  final String? note;
  final int? course;
  final int submissionNo;
  final bool cancelled;
  final List<int> modifierIds;
}

/// State of the part of an order one station has to prepare.
class Ticket {
  const Ticket({
    required this.id,
    required this.stationId,
    required this.submissionNo,
    required this.kind,
    required this.status,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: (json['id'] as num).toInt(),
    stationId: (json['stationId'] as num).toInt(),
    submissionNo: (json['submissionNo'] as num).toInt(),
    kind: _kind(json['kind'] as String),
    status: _status(json['status'] as String),
  );

  final int id;
  final int stationId;
  final int submissionNo;
  final TicketKind kind;
  final TicketStatus status;
}

class Order {
  const Order({
    required this.id,
    required this.tableId,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.tickets,
    this.note,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    tableId: (json['tableId'] as num).toInt(),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    note: json['note'] as String?,
    items: [
      for (final item in (json['items'] as List<dynamic>? ?? <dynamic>[]))
        OrderItem.fromJson(item as Map<String, dynamic>),
    ],
    tickets: [
      for (final ticket in (json['tickets'] as List<dynamic>? ?? <dynamic>[]))
        Ticket.fromJson(ticket as Map<String, dynamic>),
    ],
  );

  final String id;
  final int tableId;

  /// DRAFT, SUBMITTED, COMPLETED or CANCELLED.
  final String status;
  final DateTime createdAt;
  final String? note;
  final List<OrderItem> items;
  final List<Ticket> tickets;

  bool get open => status == 'SUBMITTED';

  /// The number the next follow-up submission gets.
  int get nextSubmissionNo {
    var last = 0;
    for (final item in items) {
      if (item.submissionNo > last) {
        last = item.submissionNo;
      }
    }
    return last + 1;
  }

  /// Latest ticket state per station, ignoring storno tickets: "is it ready to serve?"
  Map<int, TicketStatus> get statusByStation {
    final result = <int, TicketStatus>{};
    for (final ticket in tickets) {
      if (ticket.kind == TicketKind.storno) {
        continue;
      }
      final current = result[ticket.stationId];
      // the least advanced ticket of a station decides
      if (current == null || ticket.status.index < current.index) {
        result[ticket.stationId] = ticket.status;
      }
    }
    return result;
  }
}
