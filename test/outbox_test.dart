import 'package:bonflow_app/core/network/api_error.dart';
import 'package:bonflow_app/core/storage/local_store.dart';
import 'package:bonflow_app/features/order/application/outbox_controller.dart';
import 'package:bonflow_app/features/order/data/order_models.dart';
import 'package:bonflow_app/features/order/data/orders_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  const lines = [NewLine(articleId: 100, quantity: 2)];

  ProviderContainer container(FlakyOrdersRepository repository, LocalStore store) {
    final c = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        localStoreProvider.overrideWithValue(store),
        outboxIntervalProvider.overrideWithValue(null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('queues while offline, persists, and sends once the server is back', () async {
    final repository = FlakyOrdersRepository();
    final store = MemoryLocalStore();
    final first = container(repository, store);
    final outbox = first.read(outboxControllerProvider.notifier);

    final sent = await outbox.submit(id: 'a', tableId: 10, lines: lines);

    expect(sent, isFalse);
    expect(first.read(outboxControllerProvider).pending, hasLength(1));

    await pumpEventQueue(); // let the background retry of the first run finish

    // a restarted app finds the order again and sends it
    repository.online = true;
    final second = container(repository, store);
    await second.read(outboxControllerProvider.notifier).flush();

    expect(second.read(outboxControllerProvider).pending, isEmpty);
    expect(repository.submitted, hasLength(1));
    expect(repository.submitted.single.single.quantity, 2);
  });

  test('sends directly when online', () async {
    final repository = FlakyOrdersRepository()..online = true;
    final c = container(repository, MemoryLocalStore());

    final sent = await c
        .read(outboxControllerProvider.notifier)
        .submit(id: 'a', tableId: 10, lines: lines);

    expect(sent, isTrue);
    expect(c.read(outboxControllerProvider).pending, isEmpty);
  });

  test('a rejected order is not retried forever', () async {
    final repository = _RejectingRepository();
    final c = container(repository, MemoryLocalStore());
    final outbox = c.read(outboxControllerProvider.notifier);
    repository.reject = false;
    await outbox.submit(id: 'a', tableId: 10, lines: lines);
    repository.reject = true;

    await outbox.flush();

    final state = c.read(outboxControllerProvider);
    expect(state.pending, isEmpty);
    expect(state.dropped, 1);
  });

  test('a validation error on direct send is thrown, not queued', () async {
    final repository = _RejectingRepository()..reject = true;
    final c = container(repository, MemoryLocalStore());

    await expectLater(
      c
          .read(outboxControllerProvider.notifier)
          .submit(id: 'a', tableId: 10, lines: lines),
      throwsA(isA<ApiError>()),
    );
    expect(c.read(outboxControllerProvider).pending, isEmpty);
  });
}

class _RejectingRepository extends FlakyOrdersRepository {
  bool reject = false;

  @override
  Future<Order> submit({
    required String id,
    required int tableId,
    required List<NewLine> lines,
    String? note,
  }) {
    throw ApiError(
      kind: reject ? ApiErrorKind.rejected : ApiErrorKind.offline,
    );
  }
}
