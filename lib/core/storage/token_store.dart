import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The logged-in waiter and the tokens of the API.
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.waiterId,
    required this.waiterName,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      waiterId: (json['waiterId'] as num).toInt(),
      waiterName: json['waiterName'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int waiterId;
  final String waiterName;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'waiterId': waiterId,
    'waiterName': waiterName,
  };

  Session withTokens(String accessToken, String refreshToken) => Session(
    accessToken: accessToken,
    refreshToken: refreshToken,
    waiterId: waiterId,
    waiterName: waiterName,
  );
}

/// Persists the session so a waiter stays logged in across app restarts.
abstract class TokenStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'bonflow.session';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) {
      return null;
    }
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.session]);

  Session? session;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore();
});
