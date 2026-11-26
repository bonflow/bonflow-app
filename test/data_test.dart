import 'dart:convert';

import 'package:bonflow_app/core/storage/local_store.dart';
import 'package:bonflow_app/features/masterdata/data/master_data_repository.dart';
import 'package:bonflow_app/features/order/data/order_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('MasterDataRepository', () {
    test('stores data and ETag, then revalidates with If-None-Match', () async {
      final adapter = FakeAdapter((options) {
        if (options.headers['If-None-Match'] == '"v1"') {
          return jsonResponse('', 304);
        }
        return jsonResponse(
          jsonEncode(masterDataJson),
          200,
          headers: {
            'etag': ['"v1"'],
          },
        );
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final store = MemoryLocalStore();
      final repository = MasterDataRepository(dio, store);

      final first = await repository.refresh();
      expect(first.articles.single.name, 'Cola');
      expect(store.values['bonflow.masterdata.etag'], '"v1"');

      final second = await repository.refresh();
      expect(second.articles.single.name, 'Cola');
      expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
      expect(await repository.cached(), isNotNull);
    });
  });

  group('Order', () {
    test('parses items and tickets and groups the state by station', () {
      final order = Order.fromJson(
        orderJson(
          items: [
            {
              'id': 1,
              'articleId': 100,
              'quantity': 2,
              'submissionNo': 1,
              'status': 'ACTIVE',
              'modifierIds': [5],
            },
            {
              'id': 2,
              'articleId': 100,
              'quantity': 1,
              'submissionNo': 1,
              'status': 'CANCELLED',
            },
          ],
          tickets: [
            {
              'id': 1,
              'stationId': 2,
              'submissionNo': 1,
              'kind': 'NEW',
              'status': 'IN_PROGRESS',
            },
          ],
        ),
      );

      expect(order.items, hasLength(2));
      expect(order.items.first.modifierIds, [5]);
      expect(order.items.last.cancelled, isTrue);
      expect(order.statusByStation[2], TicketStatus.inProgress);
      expect(order.nextSubmissionNo, 2);
    });
  });
}
