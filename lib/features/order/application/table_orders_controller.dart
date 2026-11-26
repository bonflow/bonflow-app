import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';

/// Open orders of the table being served.
class TableOrdersState {
  const TableOrdersState({this.orders = const [], this.loading = true, this.error});

  final List<Order> orders;
  final bool loading;
  final ApiError? error;
}

/// One instance per table screen; [tableId] is set by [TableOrdersController.open].
class TableOrdersController extends Notifier<TableOrdersState> {
  int? _tableId;

  @override
  TableOrdersState build() => const TableOrdersState();

  Future<void> open(int tableId) async {
    _tableId = tableId;
    state = const TableOrdersState();
    await reload();
  }

  Future<void> reload() async {
    final tableId = _tableId;
    if (tableId == null) {
      return;
    }
    state = TableOrdersState(orders: state.orders, loading: true);
    try {
      final orders = await ref
          .read(ordersRepositoryProvider)
          .openOrdersOfTable(tableId);
      if (!ref.mounted) {
        return;
      }
      state = TableOrdersState(orders: orders, loading: false);
    } on ApiError catch (e) {
      if (!ref.mounted) {
        return;
      }
      state = TableOrdersState(orders: state.orders, loading: false, error: e);
    }
  }
}

final tableOrdersControllerProvider =
    NotifierProvider.autoDispose<TableOrdersController, TableOrdersState>(
      TableOrdersController.new,
    );
