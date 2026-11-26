import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

BaseOptions baseOptions() => BaseOptions(
  baseUrl: '${AppConfig.apiBaseUrl}${AppConfig.apiPath}',
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(seconds: 15),
  headers: {'Accept': 'application/json'},
);

/// HTTP client without authentication, for login and token refresh.
final plainDioProvider = Provider<Dio>((ref) => Dio(baseOptions()));
