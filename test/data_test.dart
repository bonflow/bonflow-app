import 'dart:convert';

import 'package:bonflow_app/core/storage/local_store.dart';
import 'package:bonflow_app/core/ui/hex_color.dart';
import 'package:bonflow_app/features/masterdata/data/master_data.dart';
import 'package:bonflow_app/features/masterdata/data/master_data_repository.dart';
import 'package:bonflow_app/features/order/data/order_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fakes.dart';

void main() {
  group('colours', () {
    test('master data carries the configured colours', () {
      final data = MasterData.fromJson(masterDataJson);
      expect(data.areas.single.color, '#1E88E5');
      expect(data.tables.single.color, isNull);
      expect(data.categories.single.color, '#E53935');
    });

    test('hex colours are parsed and unreadable values ignored', () {
      expect(parseHexColor('#1E88E5'), const Color(0xFF1E88E5));
      expect(parseHexColor('blau'), isNull);
      expect(parseHexColor(null), isNull);
    });

    test('text colour contrasts with the background', () {
      expect(onColor(const Color(0xFFFDD835)), const Color(0xFF1B1B1B));
      expect(onColor(const Color(0xFF3949AB)), const Color(0xFFFFFFFF));
    });
  });

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
