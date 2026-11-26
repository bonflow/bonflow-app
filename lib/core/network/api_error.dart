import 'package:dio/dio.dart';

/// What went wrong with an API call, in terms the UI can react to.
class ApiError implements Exception {
  const ApiError({required this.kind, this.statusCode, this.detail});

  /// Maps a Dio failure; [detail] is taken from the RFC 9457 problem body if present.
  factory ApiError.from(Object error) {
    if (error is ApiError) {
      return error;
    }
    if (error is DioException) {
      final response = error.response;
      if (response == null) {
        return const ApiError(kind: ApiErrorKind.offline);
      }
      final data = response.data;
      final detail = data is Map ? data['detail'] as String? : null;
      final status = response.statusCode;
      return ApiError(
        kind: switch (status) {
          401 => ApiErrorKind.unauthorized,
          404 => ApiErrorKind.notFound,
          409 => ApiErrorKind.conflict,
          422 => ApiErrorKind.rejected,
          429 => ApiErrorKind.tooManyRequests,
          _ => ApiErrorKind.server,
        },
        statusCode: status,
        detail: detail,
      );
    }
    return const ApiError(kind: ApiErrorKind.server);
  }

  final ApiErrorKind kind;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'ApiError($kind, $statusCode, $detail)';
}

enum ApiErrorKind {
  /// The server could not be reached.
  offline,
  unauthorized,
  notFound,

  /// The order changed in the meantime or the request was already applied.
  conflict,

  /// A business rule was violated, [ApiError.detail] explains which.
  rejected,
  tooManyRequests,
  server,
}
