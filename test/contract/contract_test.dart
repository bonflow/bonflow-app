import 'dart:convert';
import 'dart:io';

import 'package:bonflow_app/core/storage/local_store.dart';
import 'package:bonflow_app/core/storage/token_store.dart';
import 'package:bonflow_app/features/auth/data/auth_repository.dart';
import 'package:bonflow_app/features/masterdata/data/master_data_repository.dart';
import 'package:bonflow_app/features/order/data/order_models.dart';
import 'package:bonflow_app/features/order/data/orders_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Contract test against the OpenAPI spec of bonflow-server.
///
/// The real repositories run against a fake HTTP adapter. Every request they send is checked
/// against the spec (operation exists, body matches the request schema); every response is
/// generated from the spec with *all* properties filled and parsed by the app's own code, so a
/// field the app reads but the server no longer provides makes the test fail.
///
/// The spec is `test/contract/openapi.json` (update with `tool/update_contract.sh`), or the file
/// named by the environment variable `CONTRACT_SPEC`.
void main() {
  final specPath =
      Platform.environment['CONTRACT_SPEC'] ?? 'test/contract/openapi.json';
  final spec = jsonDecode(File(specPath).readAsStringSync()) as Map<String, dynamic>;
  final contract = _Contract(spec);

  /// Dio whose adapter validates the request and answers with a generated response.
  Dio client(List<String> problems) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    dio.httpClientAdapter = FakeAdapter((options) {
      final operation = contract.operation(options.method, options.uri.path);
      if (operation == null) {
        problems.add('${options.method} ${options.uri.path} is not in the spec');
        return jsonResponse('{}', 404);
      }
      final bodySchema = operation.requestSchema;
      if (bodySchema != null) {
        final data = options.data is String
            ? jsonDecode(options.data as String)
            : options.data;
        contract.validate(
          data,
          bodySchema,
          '${options.method} ${operation.path} body',
          problems,
        );
      } else if (options.data != null) {
        problems.add('${options.method} ${operation.path} sends a body the spec does not define');
      }
      final responseSchema = operation.responseSchema;
      return jsonResponse(
        responseSchema == null ? '{}' : jsonEncode(contract.sample(responseSchema)),
        200,
      );
    });
    return dio;
  }

  const orderId = '3f2b8c1e-5d7a-4c1b-9e0a-1a2b3c4d5e6f';
  const lines = [
    NewLine(
      articleId: 100,
      quantity: 2,
      note: 'ohne Eis',
      course: 1,
      modifierIds: [1, 2],
    ),
  ];

  late List<String> problems;
  setUp(() => problems = []);
  tearDown(() => expect(problems, isEmpty));

  test('login, refresh and waiter list', () async {
    final repository = HttpAuthRepository(client(problems));

    final waiters = await repository.waiters();
    final session = await repository.login(1, '1234');
    final renewed = await repository.refresh(session);

    expect(waiters, isNotEmpty);
    expect(session.accessToken, isNotEmpty);
    expect(renewed.refreshToken, isNotEmpty);
  });

  test('master data', () async {
    final repository = MasterDataRepository(
      client(problems),
      MemoryLocalStore(),
    );

    final data = await repository.refresh();

    expect(data.articles, isNotEmpty);
    expect(data.tables, isNotEmpty);
    expect(data.modifierGroups.first.modifiers, isNotEmpty);
    expect(data.stations, isNotEmpty);
    expect(data.categories, isNotEmpty);
  });

  test('order flow', () async {
    final repository = OrdersRepository(client(problems));

    final created = await repository.submit(
      id: orderId,
      tableId: 10,
      lines: lines,
      note: 'Geburtstag',
    );
    final added = await repository.addItems(
      orderId: orderId,
      submissionNo: 2,
      lines: lines,
    );
    final cancelled = await repository.cancelItems(orderId, [1]);
    final completed = await repository.complete(orderId);
    final open = await repository.openOrdersOfTable(10);

    for (final order in [created, added, cancelled, completed, ...open]) {
      expect(order.items, isNotEmpty);
      expect(order.tickets, isNotEmpty);
    }
  });

  test('the session type matches the token response', () {
    // Session is stored on the device; it must be buildable from the login response fields.
    const session = Session(
      accessToken: 'a',
      refreshToken: 'r',
      waiterId: 1,
      waiterName: 'Anna',
    );
    expect(Session.fromJson(session.toJson()).waiterName, 'Anna');
  });
}

class _Operation {
  _Operation(this.path, this.requestSchema, this.responseSchema);

  final String path;
  final Map<String, dynamic>? requestSchema;
  final Map<String, dynamic>? responseSchema;
}

/// A minimal reader for the OpenAPI subset the server produces ($ref, objects, arrays,
/// scalars with format, enums).
class _Contract {
  _Contract(this.spec);

  final Map<String, dynamic> spec;

  Map<String, dynamic> _resolve(Map<String, dynamic> schema) {
    final ref = schema[r'$ref'] as String?;
    if (ref == null) {
      return schema;
    }
    final parts = ref.substring(2).split('/');
    dynamic node = spec;
    for (final part in parts) {
      node = (node as Map<String, dynamic>)[part];
    }
    return node as Map<String, dynamic>;
  }

  Map<String, dynamic>? _schemaOf(Map<String, dynamic>? content) {
    if (content == null) {
      return null;
    }
    for (final media in content.values) {
      final schema = (media as Map<String, dynamic>)['schema'];
      if (schema != null) {
        return schema as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// The operation for a concrete request path such as `/api/v1/orders/<uuid>/items`.
  _Operation? operation(String method, String path) {
    final paths = spec['paths'] as Map<String, dynamic>;
    for (final entry in paths.entries) {
      final pattern = RegExp(
        '^${entry.key.replaceAllMapped(RegExp(r'\{[^}]+\}'), (_) => '[^/]+')}\$',
      );
      if (!pattern.hasMatch(path)) {
        continue;
      }
      final operation =
          (entry.value as Map<String, dynamic>)[method.toLowerCase()]
              as Map<String, dynamic>?;
      if (operation == null) {
        continue;
      }
      final request = operation['requestBody'] as Map<String, dynamic>?;
      final responses = operation['responses'] as Map<String, dynamic>;
      final ok = (responses['200'] ?? responses['201']) as Map<String, dynamic>?;
      return _Operation(
        '$method ${entry.key}',
        _schemaOf(request?['content'] as Map<String, dynamic>?),
        _schemaOf(ok?['content'] as Map<String, dynamic>?),
      );
    }
    return null;
  }

  /// A value with every property of [schema] filled in.
  dynamic sample(Map<String, dynamic> schema) {
    final resolved = _resolve(schema);
    final enumValues = resolved['enum'] as List<dynamic>?;
    if (enumValues != null) {
      return enumValues.first;
    }
    switch (resolved['type']) {
      case 'object':
        final properties =
            (resolved['properties'] as Map<String, dynamic>?) ?? {};
        return {
          for (final e in properties.entries)
            e.key: sample(e.value as Map<String, dynamic>),
        };
      case 'array':
        return [sample(resolved['items'] as Map<String, dynamic>)];
      case 'integer':
        return 1;
      case 'number':
        return 1.5;
      case 'boolean':
        return true;
      case 'string':
        return switch (resolved['format']) {
          'uuid' => '3f2b8c1e-5d7a-4c1b-9e0a-1a2b3c4d5e6f',
          'date-time' => '2026-11-26T12:00:00Z',
          _ => 'x',
        };
    }
    return null;
  }

  /// Adds a message to [problems] for every way [value] violates [schema].
  void validate(
    dynamic value,
    Map<String, dynamic> schema,
    String where,
    List<String> problems,
  ) {
    final resolved = _resolve(schema);
    final enumValues = resolved['enum'] as List<dynamic>?;
    if (enumValues != null && !enumValues.contains(value)) {
      problems.add('$where: $value is not one of $enumValues');
      return;
    }
    switch (resolved['type']) {
      case 'object':
        if (value is! Map) {
          problems.add('$where: expected an object, got ${value.runtimeType}');
          return;
        }
        final properties =
            (resolved['properties'] as Map<String, dynamic>?) ?? {};
        for (final required in (resolved['required'] as List<dynamic>? ?? [])) {
          if (!value.containsKey(required)) {
            problems.add('$where: required property "$required" is missing');
          }
        }
        for (final entry in value.entries) {
          final property = properties[entry.key];
          if (property == null) {
            problems.add('$where: property "${entry.key}" is not in the spec');
          } else {
            validate(
              entry.value,
              property as Map<String, dynamic>,
              '$where.${entry.key}',
              problems,
            );
          }
        }
      case 'array':
        if (value is! List) {
          problems.add('$where: expected an array, got ${value.runtimeType}');
          return;
        }
        final min = resolved['minItems'] as num?;
        final max = resolved['maxItems'] as num?;
        if (min != null && value.length < min || max != null && value.length > max) {
          problems.add('$where: ${value.length} items violates the size limits');
        }
        for (var i = 0; i < value.length; i++) {
          validate(
            value[i],
            resolved['items'] as Map<String, dynamic>,
            '$where[$i]',
            problems,
          );
        }
      case 'integer':
        if (value is! int) {
          problems.add('$where: expected an integer, got ${value.runtimeType}');
          return;
        }
        _checkRange(value, resolved, where, problems);
      case 'number':
        if (value is! num) {
          problems.add('$where: expected a number, got ${value.runtimeType}');
        }
      case 'boolean':
        if (value is! bool) {
          problems.add('$where: expected a boolean, got ${value.runtimeType}');
        }
      case 'string':
        if (value is! String) {
          problems.add('$where: expected a string, got ${value.runtimeType}');
          return;
        }
        final maxLength = resolved['maxLength'] as num?;
        final minLength = resolved['minLength'] as num?;
        if (maxLength != null && value.length > maxLength ||
            minLength != null && value.length < minLength) {
          problems.add('$where: length ${value.length} violates the limits');
        }
        if (resolved['format'] == 'uuid' &&
            !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
                .hasMatch(value)) {
          problems.add('$where: "$value" is not a UUID');
        }
    }
  }

  void _checkRange(
    num value,
    Map<String, dynamic> schema,
    String where,
    List<String> problems,
  ) {
    final min = schema['minimum'] as num?;
    final max = schema['maximum'] as num?;
    if (min != null && value < min || max != null && value > max) {
      problems.add('$where: $value is outside $min..$max');
    }
  }
}
