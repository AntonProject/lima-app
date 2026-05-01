# LIMA Project Map

## Product

LIMA is a Flutter app for medical representatives. It supports daily field work: planning and conducting visits, working with ЛПУ and pharmacies, choosing doctors, showing drug materials, recording orders/remnants, and continuing work with unstable internet.

The app is offline-first: data is read from local SQLite, user actions are written locally first, and sync reconciles with the API when network is available.

## Stack

- Flutter + Dart
- Riverpod for state
- GoRouter for navigation
- Dio for API
- SQLite via `sqflite`
- SharedPreferences and secure storage for local state/auth
- `connectivity_plus` for network state
- `path_provider` and local assets for files/materials

## Key Files

- `lib/main.dart` - bootstrap and SharedPreferences override.
- `lib/app.dart` - root `MaterialApp.router`, localization, auth/network listeners.
- `lib/core/router/app_router.dart` - routes and protected navigation.
- `lib/core/network/api_client.dart` - Dio client, token, base URL normalization.
- `lib/core/network/remote_api_service.dart` - API methods and fallback paths.
- `lib/core/db/local_database.dart` - SQLite schema, migrations, local read/write.
- `lib/core/providers/sync_provider.dart` - pull, push, delta sync, reconciliation.
- `lib/core/providers/app_collections_provider.dart` - app data collections for screens.
- `lib/shell/main_shell.dart` - main shell and online/offline sync trigger.
- `lib/features/offline/screens/sync_screen.dart` - manual sync and diagnostics.

## Feature Areas

- `lib/features/auth` - login and auth state.
- `lib/features/home` - dashboard/home.
- `lib/features/plan` - visit plan.
- `lib/features/visits` - ЛПУ/pharmacy visits, history, map, order, stock, circle flows.
- `lib/features/knowledge` - drug knowledge base and materials.
- `lib/features/offline` - sync screen.
- `lib/features/profile` - profile and favorites.
- `lib/features/cart` - cart/drafts.
- `lib/features/notifications` - notifications.

## Documentation Index

- `README.md` - product and architecture overview.
- `ARCHITECTURE_SYNC.md` - API/sync endpoints and flow.
- `OFFLINE_DB.md` - SQLite schema and offline-first rules.
- `WORKFLOW_AGENT.md` - older/agent web workflow reference.

## When Changing API Or Sync

Read:

- `ARCHITECTURE_SYNC.md`
- `OFFLINE_DB.md` if local schema/offline behavior changes
- `lib/core/network/remote_api_service.dart`
- `lib/core/providers/sync_provider.dart`
- `lib/core/db/local_database.dart`

Update docs when API contracts, fallback paths, schema, migrations, or offline behavior change.
