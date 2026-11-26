import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small key/value store for non-secret data (master data cache and its ETag).
abstract class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesLocalStore implements LocalStore {
  PreferencesLocalStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

class MemoryLocalStore implements LocalStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

final localStoreProvider = Provider<LocalStore>((ref) {
  return PreferencesLocalStore();
});
