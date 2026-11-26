/// Build-time configuration, set with `--dart-define`, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://bonflow.lan`.
class AppConfig {
  const AppConfig._();

  /// Base URL of bonflow-server (without `/api/v1`).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bonflow.lan',
  );

  static const apiPath = '/api/v1';
}
