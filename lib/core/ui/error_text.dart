import '../../l10n/generated/app_localizations.dart';
import '../network/api_error.dart';

/// User-facing text for a failed API call.
String errorText(AppLocalizations l10n, Object error) {
  final apiError = ApiError.from(error);
  return switch (apiError.kind) {
    ApiErrorKind.offline => l10n.errorOffline,
    ApiErrorKind.conflict => l10n.errorConflict,
    ApiErrorKind.rejected => apiError.detail ?? l10n.errorGeneric,
    _ => l10n.errorGeneric,
  };
}
