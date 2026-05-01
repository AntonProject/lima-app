# Agent Instructions For LIMA

LIMA is a Flutter/Dart offline-first mobile app for medical representatives. Treat this as a working production-style app, not a starter template.

## First Read

Before broad exploration, read only the smallest relevant context:

- `docs/agent-context/PROJECT_MAP.md` for the quick project map.
- `docs/agent-context/commands.md` for validation/run commands.
- `docs/agent-context/safe-zones.md` for edit boundaries.
- `README.md` for product and architecture overview.
- `ARCHITECTURE_SYNC.md` only for API/sync changes.
- `OFFLINE_DB.md` only for SQLite/offline-first changes.
- `WORKFLOW_AGENT.md` only when matching behavior against the older agent web workflow.

## Core Rules

- Keep edits scoped to the requested feature, screen, file, or behavior.
- Never delete files, directories, imports, dependencies, assets, generated outputs, database fields, migrations, or large code blocks without explicit user confirmation.
- Preserve user changes in a dirty worktree. Do not revert unrelated edits.
- Do not refactor unrelated code, rename public APIs, or reorganize files unless explicitly requested.
- Do not stage, commit, push, deploy, publish, merge, rebase, tag, or open PRs unless explicitly requested.
- Use subagents only when the user explicitly asks for agents, delegation, or parallel work.

## Project-Specific Caution

- Offline-first behavior is central. API, local DB, and provider changes must preserve local reads and pending writes.
- Sync-related changes usually involve `remote_api_service.dart`, `sync_provider.dart`, and `local_database.dart`; update docs when contracts or schema change.
- SQLite migrations and schema version changes are high-risk. Do not remove columns or reset local data without explicit confirmation.
- Platform folders and build outputs are not normal edit targets.

## Validation

- For shared logic, navigation, API, DB, sync, auth, or provider changes, run `flutter analyze` unless the user says not to.
- For tests or business logic changes, run `flutter test` or the narrowest relevant test when available.
- Use `dart format` only on touched Dart files when formatting is needed.
