import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/ui/error_text.dart';
import '../../../core/util/uuid.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../masterdata/application/master_data_controller.dart';
import '../../masterdata/data/master_data.dart';
import '../application/outbox_controller.dart';
import '../application/table_orders_controller.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';

/// Everything about one table: open orders with the state of each station, cancellations,
/// follow-up orders and the draft of new items that is sent from here.
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({required this.tableId, super.key});

  final String tableId;

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

/// Where a draft goes: [orderId] null means a new order.
class _Target {
  const _Target(this.orderId);

  final String? orderId;
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  late final int _tableId = int.parse(widget.tableId);
  final List<NewLine> _draft = [];

  /// Id of the order this draft becomes. Sending again with the same id cannot create the
  /// order twice; it changes whenever the draft changes.
  String _draftId = newUuid();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(tableOrdersControllerProvider.notifier).open(_tableId),
    );
  }

  Future<void> _addItem() async {
    final line = await context.push<NewLine>('/tables/$_tableId/order/menu');
    if (line != null && mounted) {
      setState(() {
        _draft.add(line);
        _draftId = newUuid();
      });
    }
  }

  void _removeLine(int index) {
    setState(() {
      _draft.removeAt(index);
      _draftId = newUuid();
    });
  }

  Future<_Target?> _chooseTarget(List<Order> orders) {
    final l10n = AppLocalizations.of(context);
    return showDialog<_Target>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.orderSendWhere),
        children: [
          SimpleDialogOption(
            key: const Key('target-new'),
            onPressed: () => Navigator.of(context).pop(const _Target(null)),
            child: Text(l10n.orderNewOrder),
          ),
          for (final order in orders)
            SimpleDialogOption(
              key: Key('target-${order.id}'),
              onPressed: () => Navigator.of(context).pop(_Target(order.id)),
              child: Text(l10n.orderFollowUp(_time(order.createdAt))),
            ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final orders = ref.read(tableOrdersControllerProvider).orders;
    _Target? target = const _Target(null);
    if (orders.isNotEmpty) {
      target = await _chooseTarget(orders);
    }
    if (target == null || !mounted) {
      return;
    }
    final targetOrderId = target.orderId;
    final lines = List<NewLine>.of(_draft);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      final repository = ref.read(ordersRepositoryProvider);
      var sent = true;
      if (targetOrderId == null) {
        sent = await ref
            .read(outboxControllerProvider.notifier)
            .submit(id: _draftId, tableId: _tableId, lines: lines);
      } else {
        final order = orders.firstWhere((o) => o.id == targetOrderId);
        await repository.addItems(
          orderId: order.id,
          submissionNo: order.nextSubmissionNo,
          lines: lines,
        );
      }
      if (mounted) {
        setState(() {
          _draft.clear();
          _draftId = newUuid();
        });
        messenger.showSnackBar(
          SnackBar(content: Text(sent ? l10n.orderSent : l10n.outboxQueued)),
        );
      }
    });
  }

  Future<void> _cancelItem(Order order, OrderItem item, String name) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.orderCancelConfirm(name))) {
      return;
    }
    await _run(
      () => ref.read(ordersRepositoryProvider).cancelItems(order.id, [item.id]),
    );
  }

  Future<void> _complete(Order order) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.orderCompleteConfirm)) {
      return;
    }
    await _run(() => ref.read(ordersRepositoryProvider).complete(order.id));
  }

  Future<bool> _confirm(String text) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Runs a server call, shows its error (if any) and reloads the table afterwards.
  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    await ref.read(tableOrdersControllerProvider.notifier).reload();
  }

  static String _time(DateTime time) => DateFormat.Hm().format(time.toLocal());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(masterDataControllerProvider).data;
    final state = ref.watch(tableOrdersControllerProvider);
    final label = data?.table(_tableId)?.label ?? widget.tableId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderForTable(label))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-item'),
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: Text(l10n.orderAddItems),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_busy || state.loading) const LinearProgressIndicator(),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                errorText(l10n, state.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Text(
            l10n.orderOpenOrders,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (state.orders.isEmpty && !state.loading && state.error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.orderNoOpenOrders),
            ),
          for (final order in state.orders)
            _OrderCard(
              order: order,
              data: data,
              time: _time(order.createdAt),
              onCancelItem: (item, name) => _cancelItem(order, item, name),
              onComplete: () => _complete(order),
            ),
          if (_draft.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.orderNewLines,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (var i = 0; i < _draft.length; i++)
              ListTile(
                key: Key('draft-$i'),
                title: Text(
                  '${_draft[i].quantity}× ${_articleName(data, _draft[i].articleId)}',
                ),
                subtitle: _lineDetails(data, _draft[i].modifierIds, _draft[i].note),
                trailing: IconButton(
                  tooltip: l10n.orderRemoveLine,
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeLine(i),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('send-order'),
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send),
              label: Text(l10n.orderSend),
            ),
          ],
        ],
      ),
    );
  }
}

String _articleName(MasterData? data, int articleId) =>
    data?.article(articleId)?.name ?? '#$articleId';

Widget? _lineDetails(MasterData? data, List<int> modifierIds, String? note) {
  final parts = [
    for (final id in modifierIds) data?.modifierName(id) ?? '#$id',
    if (note != null && note.trim().isNotEmpty) note.trim(),
  ];
  return parts.isEmpty ? null : Text(parts.join(' · '));
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.data,
    required this.time,
    required this.onCancelItem,
    required this.onComplete,
  });

  final Order order;
  final MasterData? data;
  final String time;
  final void Function(OrderItem item, String name) onCancelItem;
  final VoidCallback onComplete;

  String _statusText(AppLocalizations l10n, TicketStatus status) =>
      switch (status) {
        TicketStatus.newTicket => l10n.ticketNew,
        TicketStatus.inProgress => l10n.ticketInProgress,
        TicketStatus.done => l10n.ticketDone,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: Key('order-${order.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderFrom(time), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in order.statusByStation.entries)
                  Chip(
                    label: Text(
                      '${data?.stationName(entry.key) ?? '#${entry.key}'}: '
                      '${_statusText(l10n, entry.value)}',
                    ),
                  ),
              ],
            ),
            for (final item in order.items)
              _ItemRow(
                item: item,
                name: _articleName(data, item.articleId),
                details: _lineDetails(data, item.modifierIds, item.note),
                cancelledMark: l10n.orderCancelledMark,
                cancelTooltip: l10n.orderCancelItem,
                onCancel: () =>
                    onCancelItem(item, _articleName(data, item.articleId)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('complete-${order.id}'),
                onPressed: onComplete,
                child: Text(l10n.orderComplete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.name,
    required this.details,
    required this.cancelledMark,
    required this.cancelTooltip,
    required this.onCancel,
  });

  final OrderItem item;
  final String name;
  final Widget? details;
  final String cancelledMark;
  final String cancelTooltip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final strike = item.cancelled
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return ListTile(
      key: Key('item-${item.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.cancelled
            ? '${item.quantity}× $name ($cancelledMark)'
            : '${item.quantity}× $name',
        style: strike,
      ),
      subtitle: details,
      trailing: item.cancelled
          ? null
          : IconButton(
              key: Key('cancel-item-${item.id}'),
              tooltip: cancelTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: onCancel,
            ),
    );
  }
}
