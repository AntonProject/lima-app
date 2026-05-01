# LIMA Safe Zones

## Usually Safe To Edit For Feature Work

- `lib/features/<feature>/screens/`
- `lib/features/<feature>/models/`
- `lib/core/widgets/`
- `lib/core/dialogs/`
- `lib/core/i18n/app_i18n.dart` for copy/localization changes

## Edit Carefully

- `lib/core/providers/`
- `lib/core/router/app_router.dart`
- `lib/core/network/api_client.dart`
- `lib/core/network/remote_api_service.dart`
- `lib/core/db/local_database.dart`
- `lib/core/models/`
- `lib/core/services/`
- `lib/app.dart`
- `lib/main.dart`
- `pubspec.yaml`
- `assets/docs/`

## High-Risk Areas

- SQLite schema version, migrations, and data replacement logic.
- Sync push/pull/reconciliation behavior.
- Auth token storage and API base URL.
- Visit payload mapping and pending local writes.
- Platform directories: `android/`, `ios/`, `macos/`, `web/`.

## Do Not Touch Without Explicit Request

- `build/`
- `.dart_tool/`
- `ios/Pods/`
- `macos/Pods/`
- `.flutter-plugins-dependencies`
- `pubspec.lock` unless dependency changes are requested.
- Certificates, secrets, provisioning profiles, local environment files.
- Any deletion of data, migrations, assets, docs, or generated outputs.

## Deletion Rule

Never delete anything without explicit user confirmation. If deletion seems useful, name the exact path or code region and ask first.
