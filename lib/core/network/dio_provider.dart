import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Shared HTTP client. The generated OpenAPI client (`bonflow_api`) is built on top of this
/// instance; auth (bearer token + refresh) and ETag handling are added as interceptors.
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: '${AppConfig.apiBaseUrl}${AppConfig.apiPath}',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
});
