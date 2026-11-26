import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/local_store.dart';
import 'master_data.dart';

/// Loads the master data and keeps a copy on the device, so the menu is available when the
/// server cannot be reached. The server's ETag avoids transferring unchanged data.
class MasterDataRepository {
  MasterDataRepository(this._dio, this._store);

  static const _dataKey = 'bonflow.masterdata';
  static const _etagKey = 'bonflow.masterdata.etag';

  final Dio _dio;
  final LocalStore _store;

  /// The copy stored on the device, if any.
  Future<MasterData?> cached() async {
    final raw = await _store.read(_dataKey);
    if (raw == null) {
      return null;
    }
    try {
      return MasterData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Asks the server for newer data. Returns the cached data when nothing changed (304).
  Future<MasterData> refresh() async {
    final cachedData = await cached();
    final etag = cachedData == null ? null : await _store.read(_etagKey);
    try {
      final response = await _dio.get<String>(
        '/masterdata',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'If-None-Match': ?etag},
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      if (response.statusCode == 304 && cachedData != null) {
        return cachedData;
      }
      final body = response.data ?? '{}';
      final data = MasterData.fromJson(jsonDecode(body) as Map<String, dynamic>);
      await _store.write(_dataKey, body);
      final newEtag = response.headers.value('etag');
      if (newEtag != null) {
        await _store.write(_etagKey, newEtag);
      }
      return data;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }
}

final masterDataRepositoryProvider = Provider<MasterDataRepository>((ref) {
  return MasterDataRepository(
    ref.watch(dioProvider),
    ref.watch(localStoreProvider),
  );
});
