import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/storage/local_store.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';
import '../data/outbox.dart';

/// Orders waiting for the server, and how many were rejected when sending them.
class OutboxState {
  const OutboxState({this.pending = const [], this.dropped = 0});

  final List<PendingOrder> pending;
  final int dropped;
}

/// How often unsent orders are retried; `null` turns the timer off (tests).
final outboxIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 20),
);

/// New orders that cannot be sent because the server is unreachable are stored here and sent
/// later, in order. Follow-up orders are not queued: they depend on the current server state.
class OutboxController extends Notifier<OutboxState> {
  late final OutboxStore _store = OutboxStore(ref.read(localStoreProvider));
  late final Future<void> _loaded = _load();
  bool _flushing = false;

  @override
  OutboxState build() {
    final interval = ref.watch(outboxIntervalProvider);
    if (interval != null) {
      final timer = Timer.periodic(interval, (_) => flush());
      ref.onDispose(timer.cancel);
    }
    Future.microtask(() async {
      await _loaded;
      if (ref.mounted) {
        await flush();
      }
    });
    return const OutboxState();
  }

  Future<void> _load() async {
    final stored = await _store.read();
    if (ref.mounted) {
      state = OutboxState(pending: stored, dropped: state.dropped);
    }
  }

  /// Sends the order. Returns true when the server has it, false when it was queued for later.
  /// Throws [ApiError] if the server rejects it.
  Future<bool> submit({
    required String id,
    required int tableId,
    required List<NewLine> lines,
  }) async {
    await _loaded;
    try {
      await ref
          .read(ordersRepositoryProvider)
          .submit(id: id, tableId: tableId, lines: lines);
      return true;
    } on ApiError catch (e) {
      if (!_retryable(e)) {
        rethrow;
      }
      if (!ref.mounted) {
        return false;
      }
      final order = PendingOrder(id: id, tableId: tableId, lines: lines);
      final pending = [
        for (final p in state.pending)
          if (p.id != id) p,
        order,
      ];
      state = OutboxState(pending: pending, dropped: state.dropped);
      await _store.write(pending);
      return false;
    }
  }

  /// Tries to send the queued orders, oldest first; stops at the first one the server cannot
  /// be reached for.
  Future<void> flush() async {
    await _loaded;
    if (_flushing || state.pending.isEmpty || !ref.mounted) {
      return;
    }
    _flushing = true;
    try {
      for (final order in List.of(state.pending)) {
        try {
          await ref
              .read(ordersRepositoryProvider)
              .submit(id: order.id, tableId: order.tableId, lines: order.lines);
          await _remove(order, rejected: false);
        } on ApiError catch (e) {
          if (!ref.mounted || _retryable(e)) {
            break;
          }
          await _remove(order, rejected: true);
        }
        if (!ref.mounted) {
          return;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// Offline and server errors may pass; so does an expired login, which sends the waiter to
  /// the login screen where the queue is retried after the next login.
  bool _retryable(ApiError e) =>
      e.kind == ApiErrorKind.offline ||
      e.kind == ApiErrorKind.server ||
      e.kind == ApiErrorKind.unauthorized ||
      e.kind == ApiErrorKind.tooManyRequests;

  Future<void> _remove(PendingOrder order, {required bool rejected}) async {
    if (!ref.mounted) {
      return;
    }
    final pending = [
      for (final p in state.pending)
        if (p.id != order.id) p,
    ];
    state = OutboxState(
      pending: pending,
      dropped: state.dropped + (rejected ? 1 : 0),
    );
    await _store.write(pending);
  }

  void clearDropped() => state = OutboxState(pending: state.pending);
}

final outboxControllerProvider =
    NotifierProvider<OutboxController, OutboxState>(OutboxController.new);
