import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/plain_dio.dart';
import '../../../core/storage/token_store.dart';

/// A waiter as shown in the login list.
class Waiter {
  const Waiter({required this.id, required this.displayName});

  factory Waiter.fromJson(Map<String, dynamic> json) => Waiter(
    id: (json['id'] as num).toInt(),
    displayName: json['displayName'] as String,
  );

  final int id;
  final String displayName;
}

/// Login failed because the PIN is wrong.
class InvalidPinException implements Exception {
  const InvalidPinException();
}

/// The waiter is locked for a short time after too many wrong PINs.
class LockedException implements Exception {
  const LockedException(this.retryAfterSeconds);

  final int retryAfterSeconds;
}

abstract class AuthRepository {
  /// Active waiters to pick from.
  Future<List<Waiter>> waiters();

  /// @throws InvalidPinException, LockedException, ApiError
  Future<Session> login(int waiterId, String pin);

  /// Exchanges a refresh token for new tokens; throws [ApiError] (unauthorized) if it is no
  /// longer valid.
  Future<Session> refresh(Session current);
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._dio);

  /// A client without the auth interceptor.
  final Dio _dio;

  @override
  Future<List<Waiter>> waiters() async {
    try {
      final response = await _dio.get<List<dynamic>>('/auth/waiters');
      return [
        for (final item in response.data ?? <dynamic>[])
          Waiter.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<Session> login(int waiterId, String pin) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'waiterId': waiterId, 'pin': pin},
      );
      return _session(response.data!);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        throw const InvalidPinException();
      }
      if (status == 429) {
        final retryAfter = e.response?.headers.value('retry-after');
        throw LockedException(int.tryParse(retryAfter ?? '') ?? 60);
      }
      throw ApiError.from(e);
    }
  }

  @override
  Future<Session> refresh(Session current) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
      return _session(response.data!);
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  static Session _session(Map<String, dynamic> json) {
    final waiter = json['waiter'] as Map<String, dynamic>;
    return Session(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      waiterId: (waiter['id'] as num).toInt(),
      waiterName: waiter['displayName'] as String,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return HttpAuthRepository(ref.watch(plainDioProvider));
});
