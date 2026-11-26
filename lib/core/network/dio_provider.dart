import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/session_controller.dart';
import 'plain_dio.dart';

/// HTTP client of the app: sends the access token and, when the server answers 401, refreshes
/// the tokens once and repeats the request. If the refresh fails the waiter is logged out.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(baseOptions());
  dio.interceptors.add(
    _AuthInterceptor(dio, ref.read(sessionControllerProvider.notifier)),
  );
  return dio;
});

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._session);

  static const _retriedKey = 'bonflow.retried';

  final Dio _dio;
  final SessionController _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _session.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 || request.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    final refreshed = await _session.refreshTokens();
    if (!refreshed) {
      handler.next(err);
      return;
    }
    request.extra[_retriedKey] = true;
    request.headers['Authorization'] = 'Bearer ${_session.accessToken}';
    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
