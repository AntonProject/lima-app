# LIMA Testing And Validation

## Use This By Change Type

- UI-only change in one screen: inspect affected widget code, run `dart format` on touched Dart files if needed.
- Shared widgets, providers, navigation, API, DB, sync, auth, or model changes: run `flutter analyze`.
- Local database or sync changes: run `flutter analyze`; run relevant tests if present; manually reason through offline-first behavior.
- Dependency/platform changes: run `flutter pub get`, `flutter analyze`, and the requested platform run/build.

## Offline-First Checklist

For DB/sync changes, verify:

- Screens can still read from local SQLite.
- Local writes remain `is_synced = 0` until pushed.
- Push errors do not block the entire batch.
- Full refresh preserves unsynced local data.
- `sync_meta` updates still match the intended behavior.

## Report

Always report:

- Commands run.
- Pass/fail result.
- Any missing device, environment, network, or API blocker.
- Remaining risk if validation could not cover offline/API behavior.
