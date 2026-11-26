# bonflow-app

Flutter app for servers on the floor: log in, pick a table, take an order and submit it to
[bonflow-server](https://github.com/bonflow/bonflow-server), which routes it to the stations
(printers and displays). Payment is not part of this app.

The overall design is in the server repo:
[docs/architecture.md](https://github.com/bonflow/bonflow-server/blob/main/docs/architecture.md).

## Structure

Feature-first, state with Riverpod, navigation with go_router.

```
lib/
├── main.dart, app.dart, router.dart
├── core/           config (--dart-define), shared Dio client
├── features/
│   ├── login/      PIN/password login, token storage
│   ├── tables/     table overview per area
│   ├── order/      order assembly and submission (client-generated order UUID)
│   └── menu/       categories, articles, modifiers from the local master data cache
└── l10n/           ARB files (de, en), generated code in lib/l10n/generated
```

## First-time setup

This repo was scaffolded without a Flutter SDK, so the platform folders do not exist yet:

```bash
flutter create . --project-name bonflow_app --org ch.famfrehner.bonflow --platforms=android,ios
flutter pub upgrade --major-versions   # bump all packages to their latest releases
flutter pub get                        # also generates the localizations
flutter analyze && flutter test
```

Requires Flutter 3.50 / Dart 3.14 or newer. The package versions in `pubspec.yaml` are lower
bounds that were not checked against pub.dev, hence the `--major-versions` upgrade.

### Material / Cupertino

Since Flutter 3.50 Material and Cupertino are no longer part of the SDK. The app imports
`package:material_ui/material_ui.dart` and `package:cupertino_ui/cupertino_ui.dart` (already
migrated; `flutter pub upgrade --major-versions` pins their versions). See the
[migration guide](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui).

## API client

The server's OpenAPI spec is the contract. Generate the Dart client from it:

```bash
tool/generate_api.sh http://localhost:8080/v3/api-docs   # or the CI artifact openapi.json
```

then enable the `bonflow_api` path dependency in `pubspec.yaml`. The generated package under
`packages/` is committed or regenerated in CI, depending on how you want to version it.

## Run

```bash
flutter run --dart-define=API_BASE_URL=https://bonflow.lan
```

## Status

Skeleton: app shell, routes, placeholder screens, German/English strings, one widget test.
Login, master data cache (version/ETag check, survives Wi-Fi drops), order submission with
retry and the generated API client are still to be built (MVP in the architecture's phasing).
