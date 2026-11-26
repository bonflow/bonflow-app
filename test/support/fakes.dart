import 'package:bonflow_app/core/network/api_error.dart';
import 'package:bonflow_app/core/storage/local_store.dart';
import 'package:bonflow_app/core/storage/token_store.dart';
import 'package:bonflow_app/features/auth/data/auth_repository.dart';
import 'package:bonflow_app/features/masterdata/data/master_data.dart';
import 'package:bonflow_app/features/masterdata/data/master_data_repository.dart';
import 'package:bonflow_app/features/order/data/order_models.dart';
import 'package:bonflow_app/features/order/data/orders_repository.dart';
import 'package:dio/dio.dart';

const masterDataJson = <String, dynamic>{
  'areas': [
    {'id': 1, 'name': 'Terrasse', 'color': '#1E88E5'},
  ],
  'tables': [
    {'id': 10, 'areaId': 1, 'label': 'T1', 'color': null},
  ],
  'stations': [
    {'id': 1, 'name': 'Küche'},
    {'id': 2, 'name': 'Bar'},
  ],
  'categories': [
    {'id': 1, 'name': 'Getränke', 'sortOrder': 1, 'color': '#E53935'},
  ],
  'articles': [
    {
      'id': 100,
      'name': 'Cola',
      'shortName': 'Cola',
      'categoryId': 1,
      'price': 4.5,
      'stationId': 2,
      'modifierGroupIds': <int>[],
    },
  ],
  'modifierGroups': <Map<String, dynamic>>[],
};

Map<String, dynamic> orderJson({
  String id = 'o-1',
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> tickets = const [],
}) => {
  'id': id,
  'tableId': 10,
  'waiterId': 1,
  'status': 'SUBMITTED',
  'createdAt': '2026-11-26T12:00:00Z',
  'items': items,
  'tickets': tickets,
};

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.pin = '1234'});

  final String pin;

  @override
  Future<List<Waiter>> waiters() async => const [
    Waiter(id: 1, displayName: 'Anna'),
  ];

  @override
  Future<Session> login(int waiterId, String pin) async {
    if (pin != this.pin) {
      throw const InvalidPinException();
    }
    return const Session(
      accessToken: 'access',
      refreshToken: 'refresh',
      waiterId: 1,
      waiterName: 'Anna',
    );
  }

  @override
  Future<Session> refresh(Session current) async =>
      current.withTokens('access-2', 'refresh-2');
}

class FakeMasterDataRepository extends MasterDataRepository {
  FakeMasterDataRepository() : super(Dio(), MemoryLocalStore());

  final MasterData data = MasterData.fromJson(masterDataJson);

  @override
  Future<MasterData?> cached() async => data;

  @override
  Future<MasterData> refresh() async => data;
}

class FakeOrdersRepository extends OrdersRepository {
  FakeOrdersRepository() : super(Dio());

  final List<Order> open = [];
  final List<List<NewLine>> submitted = [];

  @override
  Future<Order> submit({
    required String id,
    required int tableId,
    required List<NewLine> lines,
    String? note,
  }) async {
    submitted.add(lines);
    final order = Order.fromJson(
      orderJson(
        id: id,
        items: [
          for (var i = 0; i < lines.length; i++)
            {
              'id': i + 1,
              'articleId': lines[i].articleId,
              'quantity': lines[i].quantity,
              'submissionNo': 1,
              'status': 'ACTIVE',
              'modifierIds': lines[i].modifierIds,
            },
        ],
      ),
    );
    open.add(order);
    return order;
  }

  @override
  Future<List<Order>> openOrdersOfTable(int tableId) async =>
      List.of(open);
}

/// Dio adapter that answers with prepared responses and records the requests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  String body,
  int status, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
    ...headers,
  },
);

/// Orders repository whose server can be switched off.
class FlakyOrdersRepository extends FakeOrdersRepository {
  bool online = false;

  @override
  Future<Order> submit({
    required String id,
    required int tableId,
    required List<NewLine> lines,
    String? note,
  }) {
    if (!online) {
      throw const ApiError(kind: ApiErrorKind.offline);
    }
    return super.submit(id: id, tableId: tableId, lines: lines, note: note);
  }
}
