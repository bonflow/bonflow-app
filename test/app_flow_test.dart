import 'package:bonflow_app/app.dart';
import 'package:bonflow_app/core/storage/local_store.dart';
import 'package:bonflow_app/core/storage/token_store.dart';
import 'package:bonflow_app/features/auth/data/auth_repository.dart';
import 'package:bonflow_app/features/masterdata/data/master_data_repository.dart';
import 'package:bonflow_app/features/order/data/orders_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fakes.dart';

void main() {
  late FakeOrdersRepository orders;

  Widget app({Session? session}) {
    orders = FakeOrdersRepository();
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(MemoryTokenStore(session)),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        masterDataRepositoryProvider.overrideWithValue(
          FakeMasterDataRepository(),
        ),
        ordersRepositoryProvider.overrideWithValue(orders),
      ],
      child: const BonflowApp(),
    );
  }

  testWidgets('wrong PIN keeps the login, correct PIN shows the tables', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('waiter-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pin-field')), '0000');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pin-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('pin-field')), '1234');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('table-10')), findsOneWidget);
  });

  testWidgets('a stored session skips the login', (tester) async {
    await tester.pumpWidget(
      app(
        session: const Session(
          accessToken: 'a',
          refreshToken: 'r',
          waiterId: 1,
          waiterName: 'Anna',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('table-10')), findsOneWidget);
    expect(find.byKey(const Key('waiter-1')), findsNothing);
  });

  testWidgets('takes an order at a table', (tester) async {
    await tester.pumpWidget(
      app(
        session: const Session(
          accessToken: 'a',
          refreshToken: 'r',
          waiterId: 1,
          waiterName: 'Anna',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('table-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('article-100')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quantity-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('send-order')));
    await tester.pumpAndSettle();

    expect(orders.submitted, hasLength(1));
    expect(orders.submitted.single.single.quantity, 2);
    expect(find.byKey(const Key('draft-0')), findsNothing);
    expect(find.byKey(const Key('draft-1')), findsNothing);
  });
}
