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
├── main.dart, app.dart, router.dart   (router redirects by session state)
├── core/           config (--dart-define), Dio clients, token + local storage, ApiError
├── features/
│   ├── auth/       login repository, session controller (token refresh)
│   ├── login/      waiter list + PIN dialog
│   ├── masterdata/ master data models, ETag cache, controller
│   ├── tables/     table overview per area
│   ├── order/      table detail, open orders, station status, follow-up, storno, complete
│   └── menu/       categories, articles, modifier sheet
└── l10n/           ARB files (de, en), generated code in lib/l10n/generated
```

New orders are queued on the device while the server is unreachable and sent automatically (follow-up orders and storno need the server). Not yet included: generated API client.

## First-time setup

This repo was scaffolded without a Flutter SDK, so the platform folders do not exist yet:

```bash
flutter create . --project-name bonflow_app --org ch.bonflow --platforms=android,ios
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

## API contract

The server's OpenAPI spec is the contract. The app talks to the API through hand-written
repositories; `test/contract` checks them against a snapshot of the spec
(`test/contract/openapi.json`): every request must match an operation and its request schema, and
responses generated from the spec (all properties filled) must be parsed by the app's models.

```bash
tool/update_contract.sh [tag]    # fetch the spec of a bonflow-server release (default: latest)
flutter test test/contract
```

The `contract` workflow runs this weekly against the latest server release. To use a generated
client instead, see `tool/generate_api.sh` (not used at the moment).

## Run

```bash
flutter run --dart-define=API_BASE_URL=https://bonflow.lan
```

## Status

Working: PIN login with token refresh, master data with ETag cache, table overview, order taking
(new order, follow-up, storno, completion) with station status, offline queue for new orders,
German/English strings.
