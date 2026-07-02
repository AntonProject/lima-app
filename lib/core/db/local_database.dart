import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:lima/core/utils/swallowed.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

// ─── LocalDatabase ────────────────────────────────────────────────────────────

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _db;
  final _changes = StreamController<Set<String>>.broadcast();

  Stream<Set<String>> get changes => _changes.stream;

  void _notifyChanged(Iterable<String> tables) {
    final changed = tables.where((table) => table.isNotEmpty).toSet();
    if (changed.isEmpty || _changes.isClosed) return;
    _changes.add(Set.unmodifiable(changed));
  }

  Database get db {
    if (_db == null) {
      throw StateError('LocalDatabase not initialised. Call init() first.');
    }
    return _db!;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lima.db');

    _db = await openDatabase(
      path,
      version: 20,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureOptionalColumns();
  }

  static const _ownerUserIdKey = 'owner_user_id';
  static const _ownerLoginKey = 'owner_login';
  static const _ownerRoleKey = 'owner_role';

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE organisations (
        id          INTEGER PRIMARY KEY,
        name        TEXT,
        name_ru     TEXT,
        address     TEXT,
        type        TEXT,
        type_id     INTEGER,
        type_name   TEXT,
        city        TEXT,
        region_id   INTEGER,
        region_name TEXT,
        district    TEXT,
        area_id     INTEGER,
        area_name   TEXT,
        inn         TEXT,
        pinfl       TEXT,
        brand       TEXT,
        category    TEXT,
        category_id INTEGER,
        responsible TEXT,
        phone       TEXT,
        phone2      TEXT,
        phone3      TEXT,
        health_care_facility_type_id    INTEGER,
        health_care_facility_type_name  TEXT,
        classification_id    INTEGER,
        classification_name  TEXT,
        med_rep_id   INTEGER,
        med_rep_name TEXT,
        visited      INTEGER DEFAULT 0,
        is_budget    INTEGER DEFAULT 0,
        date_create  TEXT,
        revision_status TEXT,
        latitude    REAL,
        longitude   REAL,
        distance_m  REAL,
        is_favorite INTEGER DEFAULT 0,
        updated_at  TEXT,
        sync_id     INTEGER,
        raw_json    TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE doctors (
        id               INTEGER PRIMARY KEY,
        full_name        TEXT,
        specialty        TEXT,
        organisation_id  INTEGER,
        is_favorite      INTEGER DEFAULT 0,
        category         TEXT,
        last_visit_label TEXT,
        updated_at       TEXT,
        sync_id          INTEGER,
        raw_json         TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE doctor_organisations (
        doctor_id       INTEGER NOT NULL,
        organisation_id INTEGER NOT NULL,
        sync_id         INTEGER,
        raw_json        TEXT,
        PRIMARY KEY (doctor_id, organisation_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE drugs (
        id               INTEGER PRIMARY KEY,
        name             TEXT,
        manufacturer     TEXT,
        price            REAL DEFAULT 0,
        serial_number    TEXT,
        expiry_date      TEXT,
        main_stock       INTEGER,
        stock            INTEGER,
        remains_stock    INTEGER,
        current_stock_id INTEGER,
        binding_drug_id  INTEGER,
        documents_count  INTEGER DEFAULT 0,
        updated_at       TEXT,
        sync_id          INTEGER,
        raw_json         TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE drug_materials (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        drug_id      INTEGER,
        title        TEXT,
        description  TEXT,
        file_type    TEXT,
        local_path   TEXT,
        cached_path  TEXT,
        uploaded_at  TEXT,
        is_mandatory INTEGER DEFAULT 0,
        raw_json     TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE visits (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id   INTEGER,
        org_id      INTEGER,
        org_name    TEXT NOT NULL,
        doctor_id   INTEGER,
        doctor_name TEXT,
        visit_type  TEXT DEFAULT 'lpu',
        status      TEXT DEFAULT 'planned',
        notes       TEXT,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        is_synced   INTEGER DEFAULT 0,
        sync_failed INTEGER DEFAULT 0,
        raw_json    TEXT,
        last_push_request_json  TEXT,
        last_push_response_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE planned_visits (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id    INTEGER UNIQUE,
        org_id       INTEGER,
        org_name     TEXT NOT NULL,
        org_type     TEXT DEFAULT 'lpu',
        doctor_id    INTEGER,
        doctor_name  TEXT,
        assigned_by  TEXT,
        city         TEXT,
        district     TEXT,
        visit_date   TEXT NOT NULL,
        status       TEXT DEFAULT 'planned',
        comment      TEXT,
        raw_json     TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE day_types (
        id       INTEGER PRIMARY KEY,
        name     TEXT,
        raw_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE visit_formats (
        id       INTEGER PRIMARY KEY,
        name     TEXT,
        raw_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE managers (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name  TEXT UNIQUE,
        role       TEXT,
        initials   TEXT,
        raw_json   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_stats (
        key        TEXT PRIMARY KEY,
        value      TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_doctors (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        temp_local_id     INTEGER NOT NULL,
        org_id            INTEGER NOT NULL,
        full_name         TEXT NOT NULL,
        specialty         TEXT NOT NULL,
        specialization_id INTEGER,
        phone             TEXT,
        hobby             TEXT,
        interests         TEXT,
        birthday          TEXT,
        created_at        TEXT NOT NULL,
        failed            INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_org_updates (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        org_id      INTEGER NOT NULL,
        name        TEXT NOT NULL,
        address     TEXT NOT NULL,
        phone       TEXT,
        city        TEXT,
        district    TEXT,
        inn         TEXT,
        category    TEXT,
        responsible TEXT,
        latitude    REAL,
        longitude   REAL,
        created_at  TEXT NOT NULL,
        UNIQUE(org_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_plans (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        local_plan_id   INTEGER NOT NULL,
        org_id          INTEGER NOT NULL,
        org_type        TEXT,
        doctor_ids_json TEXT,
        visit_format_id INTEGER NOT NULL,
        start_date      TEXT NOT NULL,
        end_date        TEXT NOT NULL,
        comment         TEXT,
        created_at      TEXT NOT NULL,
        UNIQUE(local_plan_id)
      )
    ''');

    await db.execute(_createPendingOrganizationsSql);
  }

  // Offline-created organisations (pharmacies) awaiting push. temp_local_id is
  // the negative id used in the `organisations` table until the server assigns
  // a real one (mirrors the pending_doctors flow).
  static const String _createPendingOrganizationsSql = '''
      CREATE TABLE IF NOT EXISTS pending_organizations (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        temp_local_id   INTEGER NOT NULL,
        name            TEXT NOT NULL,
        inn             TEXT NOT NULL,
        type_id         INTEGER NOT NULL,
        region_id       INTEGER NOT NULL,
        area_id         INTEGER,
        phone           TEXT,
        phone2          TEXT,
        phone3          TEXT,
        address         TEXT,
        category_id     INTEGER,
        hcf_type_id     INTEGER,
        revision_status TEXT,
        responsible     TEXT,
        latitude        REAL,
        longitude       REAL,
        created_at      TEXT NOT NULL,
        UNIQUE(temp_local_id)
      )
    ''';

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN latitude REAL');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN longitude REAL');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute(
          'ALTER TABLE organisations ADD COLUMN distance_m REAL',
        );
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
    }
    if (oldVersion < 3) {
      await _ensureRawAndSyncColumns(db);
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN phone TEXT');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN district TEXT');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN inn TEXT');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN category TEXT');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute(
          'ALTER TABLE organisations ADD COLUMN responsible TEXT',
        );
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE organisations ADD COLUMN is_favorite INTEGER DEFAULT 0',
        );
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS planned_visits (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            remote_id    INTEGER UNIQUE,
            org_id       INTEGER,
            org_name     TEXT NOT NULL,
            org_type     TEXT DEFAULT 'lpu',
            doctor_id    INTEGER,
            doctor_name  TEXT,
            assigned_by  TEXT,
            city         TEXT,
            visit_date   TEXT NOT NULL,
            status       TEXT DEFAULT 'planned',
            comment      TEXT,
            raw_json     TEXT
          )
        ''');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS day_types (
            id       INTEGER PRIMARY KEY,
            name     TEXT,
            raw_json TEXT
          )
        ''');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS managers (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name  TEXT UNIQUE,
            role       TEXT,
            initials   TEXT,
            raw_json   TEXT
          )
        ''');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_stats (
            key        TEXT PRIMARY KEY,
            value      TEXT,
            updated_at TEXT
          )
        ''');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pending_doctors (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            temp_local_id INTEGER NOT NULL,
            org_id        INTEGER NOT NULL,
            full_name     TEXT NOT NULL,
            specialty     TEXT NOT NULL,
            phone         TEXT,
            created_at    TEXT NOT NULL
          )
        ''');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pending_org_updates (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            org_id      INTEGER NOT NULL,
            name        TEXT NOT NULL,
            address     TEXT NOT NULL,
            phone       TEXT,
            city        TEXT,
            district    TEXT,
            inn         TEXT,
            category    TEXT,
            responsible TEXT,
            latitude    REAL,
            longitude   REAL,
            created_at  TEXT NOT NULL,
            UNIQUE(org_id)
          )
        ''');
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
    }
    if (oldVersion < 9) {
      await _ensureRegionColumns(db);
    }
    if (oldVersion < 10) {
      await _ensureDoctorOrganisationTable(db);
    }
    if (oldVersion < 15) {
      await _ensureVisitRetryColumns(db);
    }
    if (oldVersion < 16) {
      await _ensureSyncFailureColumns(db);
    }
    if (oldVersion < 17) {
      try {
        await db.execute(_createPendingOrganizationsSql);
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
    }
    if (oldVersion < 18) {
      // LPU fields on the offline-create queue (added with the LPU form).
      for (final sql in const [
        'ALTER TABLE pending_organizations ADD COLUMN phone2 TEXT',
        'ALTER TABLE pending_organizations ADD COLUMN phone3 TEXT',
        'ALTER TABLE pending_organizations ADD COLUMN hcf_type_id INTEGER',
        'ALTER TABLE pending_organizations ADD COLUMN revision_status TEXT',
      ]) {
        try {
          await db.execute(sql);
        } catch (e) {
          logSwallowed(e, 'LocalDatabase._onUpgrade');
        }
      }
    }
    if (oldVersion < 19) {
      // Mirror all server organisation fields as real columns (previously only
      // a subset was promoted; the rest lived in raw_json only).
      for (final sql in const [
        'ALTER TABLE organisations ADD COLUMN name_ru TEXT',
        'ALTER TABLE organisations ADD COLUMN type_id INTEGER',
        'ALTER TABLE organisations ADD COLUMN type_name TEXT',
        'ALTER TABLE organisations ADD COLUMN region_name TEXT',
        'ALTER TABLE organisations ADD COLUMN area_name TEXT',
        'ALTER TABLE organisations ADD COLUMN pinfl TEXT',
        'ALTER TABLE organisations ADD COLUMN brand TEXT',
        'ALTER TABLE organisations ADD COLUMN category_id INTEGER',
        'ALTER TABLE organisations ADD COLUMN phone2 TEXT',
        'ALTER TABLE organisations ADD COLUMN phone3 TEXT',
        'ALTER TABLE organisations ADD COLUMN health_care_facility_type_id INTEGER',
        'ALTER TABLE organisations ADD COLUMN health_care_facility_type_name TEXT',
        'ALTER TABLE organisations ADD COLUMN classification_id INTEGER',
        'ALTER TABLE organisations ADD COLUMN classification_name TEXT',
        'ALTER TABLE organisations ADD COLUMN med_rep_id INTEGER',
        'ALTER TABLE organisations ADD COLUMN med_rep_name TEXT',
        'ALTER TABLE organisations ADD COLUMN visited INTEGER DEFAULT 0',
        'ALTER TABLE organisations ADD COLUMN is_budget INTEGER DEFAULT 0',
        'ALTER TABLE organisations ADD COLUMN date_create TEXT',
        'ALTER TABLE organisations ADD COLUMN revision_status TEXT',
      ]) {
        try {
          await db.execute(sql);
        } catch (e) {
          logSwallowed(e, 'LocalDatabase._onUpgrade');
        }
      }
    }
    if (oldVersion < 20) {
      // Park pending_doctors rows that can never be pushed (see
      // markPendingDoctorFailed) instead of deleting them silently.
      try {
        await db.execute(
          'ALTER TABLE pending_doctors ADD COLUMN failed INTEGER DEFAULT 0',
        );
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._onUpgrade');
      }
    }
  }

  Future<void> _ensureOptionalColumns() async {
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN latitude REAL');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN longitude REAL');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN distance_m REAL');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN phone TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN district TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    await _ensureRegionColumns(db);
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN inn TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN category TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN responsible TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN serial_number TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN expiry_date TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN stock INTEGER');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN main_stock INTEGER');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN remains_stock INTEGER');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN current_stock_id INTEGER');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN binding_drug_id INTEGER');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
    }
    // Full add-doctor payload for the offline queue (matches the web API).
    for (final col in const [
      'ALTER TABLE pending_doctors ADD COLUMN specialization_id INTEGER',
      'ALTER TABLE pending_doctors ADD COLUMN hobby TEXT',
      'ALTER TABLE pending_doctors ADD COLUMN interests TEXT',
      'ALTER TABLE pending_doctors ADD COLUMN birthday TEXT',
    ]) {
      try {
        await db.execute(col);
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._ensureOptionalColumns');
      }
    }
    await _ensureRawAndSyncColumns(db);
    await _ensureDoctorOrganisationTable(db);
    await _ensureVisitRetryColumns(db);
    await _ensureSyncFailureColumns(db);
  }

  Future<void> _ensureDoctorOrganisationTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS doctor_organisations (
        doctor_id       INTEGER NOT NULL,
        organisation_id INTEGER NOT NULL,
        sync_id         INTEGER,
        raw_json        TEXT,
        PRIMARY KEY (doctor_id, organisation_id)
      )
    ''');
  }

  /// Columns supporting retry/backoff for unsynced visits (schema v15).
  /// [push_attempts] counts failed push tries; [next_retry_at] holds the ISO
  /// timestamp before which a visit should not be retried.
  Future<void> _ensureVisitRetryColumns(Database database) async {
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN push_attempts INTEGER DEFAULT 0',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureVisitRetryColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN next_retry_at TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureVisitRetryColumns');
    }
  }

  /// Columns supporting "failed, kept for the user" semantics (schema v16).
  /// [visits.sync_failed] marks a visit the push loop gave up on: the row stays
  /// in the DB (is_synced remains 0) but is excluded from automatic pushes
  /// until the user retries or deletes it from the sync screen.
  /// [pending_favorites]/[pending_feedback] gain the same attempts/failed pair
  /// so their queue items stop retrying forever but are never silently lost.
  Future<void> _ensureSyncFailureColumns(Database database) async {
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN sync_failed INTEGER DEFAULT 0',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureSyncFailureColumns');
    }
    for (final table in ['pending_favorites', 'pending_feedback']) {
      try {
        await database.execute(
          'ALTER TABLE $table ADD COLUMN attempts INTEGER DEFAULT 0',
        );
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._ensureSyncFailureColumns');
      }
      try {
        await database.execute(
          'ALTER TABLE $table ADD COLUMN failed INTEGER DEFAULT 0',
        );
      } catch (e) {
        logSwallowed(e, 'LocalDatabase._ensureSyncFailureColumns');
      }
    }
  }

  Future<void> _ensureRegionColumns(Database database) async {
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN region_id INTEGER',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRegionColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN area_id INTEGER',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRegionColumns');
    }
  }

  Future<void> _ensureRawAndSyncColumns(Database database) async {
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN sync_id INTEGER',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN raw_json TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('ALTER TABLE doctors ADD COLUMN sync_id INTEGER');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('ALTER TABLE doctors ADD COLUMN raw_json TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('ALTER TABLE drugs ADD COLUMN sync_id INTEGER');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('ALTER TABLE drugs ADD COLUMN raw_json TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE drug_materials ADD COLUMN raw_json TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN is_favorite INTEGER DEFAULT 0',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('ALTER TABLE visits ADD COLUMN raw_json TEXT');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN last_push_request_json TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN last_push_response_json TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE drug_materials ADD COLUMN cached_path TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE drug_materials ADD COLUMN uploaded_at TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN medical_rep_name TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS pending_feedback (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          message     TEXT NOT NULL,
          photo_paths TEXT,
          created_at  TEXT NOT NULL
        )
      ''');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS pending_favorites (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type  TEXT NOT NULL,
          entity_id    INTEGER NOT NULL,
          action       TEXT NOT NULL,
          created_at   TEXT NOT NULL,
          UNIQUE(entity_type, entity_id)
        )
      ''');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS pending_plans (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          local_plan_id   INTEGER NOT NULL,
          org_id          INTEGER NOT NULL,
          org_type        TEXT,
          doctor_ids_json TEXT,
          visit_format_id INTEGER NOT NULL,
          start_date      TEXT NOT NULL,
          end_date        TEXT NOT NULL,
          comment         TEXT,
          created_at      TEXT NOT NULL,
          UNIQUE(local_plan_id)
        )
      ''');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE planned_visits ADD COLUMN district TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute(
        'ALTER TABLE planned_visits ADD COLUMN visit_format TEXT',
      );
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
    try {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS visit_formats (
          id       INTEGER PRIMARY KEY,
          name     TEXT,
          raw_json TEXT
        )
      ''');
    } catch (e) {
      logSwallowed(e, 'LocalDatabase._ensureRawAndSyncColumns');
    }
  }

  // ── Pending favorites queue ───────────────────────────────────────────────

  /// Upserts favorite toggle. Replaces previous pending action for same entity.
  Future<void> enqueueFavorite({
    required String entityType,
    required int entityId,
    required bool add,
  }) async {
    await db.insert('pending_favorites', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': add ? 'add' : 'remove',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged(['pending_favorites']);
  }

  Future<List<Map<String, dynamic>>> getPendingFavorites() async {
    return db.query(
      'pending_favorites',
      where: 'failed IS NULL OR failed = 0',
      orderBy: 'id ASC',
    );
  }

  Future<void> deletePendingFavorite(int id) async {
    await db.delete('pending_favorites', where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['pending_favorites']);
  }

  /// Max push attempts for pending_favorites/pending_feedback rows before the
  /// row is parked (failed = 1). Parked rows stop retrying but stay in the DB
  /// and are surfaced as a count on the sync screen.
  static const int maxPendingQueueAttempts = 10;

  /// Increments the attempt counter for a pending-queue row and parks it once
  /// [maxPendingQueueAttempts] is reached. Returns the new attempt count.
  Future<int> _recordPendingQueueFailure(String table, int id) async {
    final rows = await db.query(
      table,
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final current = rows.isEmpty
        ? 0
        : ((rows.first['attempts'] as num?)?.toInt() ?? 0);
    final attempts = current + 1;
    await db.update(
      table,
      {
        'attempts': attempts,
        if (attempts >= maxPendingQueueAttempts) 'failed': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged([table]);
    return attempts;
  }

  Future<int> recordPendingFavoriteFailure(int id) =>
      _recordPendingQueueFailure('pending_favorites', id);

  Future<int> recordPendingFeedbackFailure(int id) =>
      _recordPendingQueueFailure('pending_feedback', id);

  /// Counts of parked queue rows, for the sync diagnostics screen.
  Future<({int favorites, int feedback})> failedPendingCounts() async {
    Future<int> countFrom(String table) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM $table WHERE failed = 1',
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    }

    return (
      favorites: await countFrom('pending_favorites'),
      feedback: await countFrom('pending_feedback'),
    );
  }

  // ── Pending feedback queue ────────────────────────────────────────────────

  Future<void> enqueueFeedback(String message, List<String> photoPaths) async {
    await db.insert('pending_feedback', {
      'message': message,
      'photo_paths': jsonEncode(photoPaths),
      'created_at': DateTime.now().toIso8601String(),
    });
    _notifyChanged(['pending_feedback']);
  }

  Future<List<Map<String, dynamic>>> getPendingFeedback() async {
    return db.query(
      'pending_feedback',
      where: 'failed IS NULL OR failed = 0',
      orderBy: 'id ASC',
    );
  }

  Future<void> deletePendingFeedback(int id) async {
    await db.delete('pending_feedback', where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['pending_feedback']);
  }

  // ── Pending doctors queue ─────────────────────────────────────────────────

  /// Сохраняет запрос на создание врача в очередь.
  /// [tempLocalId] — отрицательный id, под которым врач уже вставлен в таблицу doctors.
  Future<void> enqueuePendingDoctor({
    required int tempLocalId,
    required int orgId,
    required String fullName,
    required String specialty,
    int? specializationId,
    String? phone,
    String? hobby,
    String? interests,
    String? birthday,
  }) async {
    await db.insert('pending_doctors', {
      'temp_local_id': tempLocalId,
      'org_id': orgId,
      'full_name': fullName,
      'specialty': specialty,
      'specialization_id': specializationId,
      'phone': phone,
      'hobby': hobby,
      'interests': interests,
      'birthday': birthday,
      'created_at': DateTime.now().toIso8601String(),
    });
    _notifyChanged(['pending_doctors']);
  }

  /// Rows still eligible for push (excludes parked/[failed] ones).
  Future<List<Map<String, dynamic>>> getPendingDoctors() async {
    return db.query(
      'pending_doctors',
      where: 'failed IS NULL OR failed = 0',
      orderBy: 'id ASC',
    );
  }

  /// Rows the push loop gave up on — see [markPendingDoctorFailed]. Surfaced
  /// on the sync screen so the offline-entered doctor isn't silently lost.
  Future<List<Map<String, dynamic>>> getFailedPendingDoctors() async {
    return db.query('pending_doctors', where: 'failed = 1', orderBy: 'id ASC');
  }

  Future<void> deletePendingDoctor(int id) async {
    await db.delete('pending_doctors', where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['pending_doctors']);
  }

  /// Parks a pending_doctors row that can never satisfy the API (e.g. queued
  /// before specialization became required) instead of deleting it — keeps
  /// the offline-entered doctor visible until the user deletes it themselves.
  Future<void> markPendingDoctorFailed(int id) async {
    await db.update(
      'pending_doctors',
      {'failed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged(['pending_doctors']);
  }

  /// После успешной синхронизации заменяет temp id на реальный remote id во всех таблицах.
  Future<void> replaceDoctorTempId(int tempId, int remoteId) async {
    await db.update(
      'doctors',
      {'id': remoteId},
      where: 'id = ?',
      whereArgs: [tempId],
    );
    await db.update(
      'visits',
      {'doctor_id': remoteId},
      where: 'doctor_id = ?',
      whereArgs: [tempId],
    );
    _notifyChanged(['doctors', 'visits']);
  }

  // ── Offline-created organisations (pharmacies) ────────────────────────────

  /// Inserts a locally-created organisation row (negative temp id) so it shows
  /// in the list immediately, before the server assigns a real id.
  Future<void> insertLocalOrganisation(Map<String, dynamic> row) async {
    await db.insert(
      'organisations',
      Map<String, dynamic>.from(row),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged(['organisations']);
  }

  Future<void> enqueuePendingOrganization({
    required int tempLocalId,
    required String name,
    required String inn,
    required int typeId,
    required int regionId,
    int? areaId,
    String? phone,
    String? phone2,
    String? phone3,
    String? address,
    int? categoryId,
    int? healthCareFacilityTypeId,
    String? revisionStatus,
    String? responsible,
    double? latitude,
    double? longitude,
  }) async {
    await db.insert('pending_organizations', {
      'temp_local_id': tempLocalId,
      'name': name,
      'inn': inn,
      'type_id': typeId,
      'region_id': regionId,
      'area_id': areaId,
      'phone': phone,
      'phone2': phone2,
      'phone3': phone3,
      'address': address,
      'category_id': categoryId,
      'hcf_type_id': healthCareFacilityTypeId,
      'revision_status': revisionStatus,
      'responsible': responsible,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged(['pending_organizations']);
  }

  Future<List<Map<String, dynamic>>> getPendingOrganizations() async {
    return db.query('pending_organizations', orderBy: 'id ASC');
  }

  Future<void> deletePendingOrganization(int id) async {
    await db.delete('pending_organizations', where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['pending_organizations']);
  }

  /// Replaces the negative temp id with the server-assigned id once pushed.
  Future<void> replaceOrganizationTempId(int tempId, int remoteId) async {
    await db.update(
      'organisations',
      {'id': remoteId},
      where: 'id = ?',
      whereArgs: [tempId],
    );
    _notifyChanged(['organisations']);
  }

  // ── Pending org updates queue ─────────────────────────────────────────────

  /// Upsert — одна запись на org_id, новый вызов перезаписывает предыдущий.
  Future<void> enqueuePendingOrgUpdate({
    required int orgId,
    required String name,
    required String address,
    String? phone,
    String? city,
    String? district,
    String? inn,
    String? category,
    String? responsible,
    double? latitude,
    double? longitude,
  }) async {
    await db.insert('pending_org_updates', {
      'org_id': orgId,
      'name': name,
      'address': address,
      'phone': phone,
      'city': city,
      'district': district,
      'inn': inn,
      'category': category,
      'responsible': responsible,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged(['pending_org_updates']);
  }

  Future<List<Map<String, dynamic>>> getPendingOrgUpdates() async {
    return db.query('pending_org_updates', orderBy: 'id ASC');
  }

  Future<void> deletePendingOrgUpdate(int id) async {
    await db.delete('pending_org_updates', where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['pending_org_updates']);
  }

  // ── Seed from remote ──────────────────────────────────────────────────────

  Future<void> seedFromRemote({
    required List<Map> orgs,
    required List<Map> doctors,
    List<Map> doctorOrgLinks = const [],
    required List<Map> drugs,
    required List<Map> materials,
    required List<Map> visits,
    List<Map> plannedVisits = const [],
    List<Map> favOrgIds = const [],
    List<Map> managers = const [],
    List<Map> dayTypes = const [],
    Map<String, dynamic>? dailyStats,
  }) async {
    final batch = db.batch();

    for (final org in orgs) {
      batch.insert(
        'organisations',
        Map<String, dynamic>.from(org),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Mark favourite organisations.
    final favIds = favOrgIds.map((e) => e['id']).whereType<int>().toSet();
    if (favIds.isNotEmpty) {
      batch.rawUpdate(
        'UPDATE organisations SET is_favorite = 0 WHERE is_favorite = 1',
      );
      for (final id in favIds) {
        batch.rawUpdate(
          'UPDATE organisations SET is_favorite = 1 WHERE id = ?',
          [id],
        );
      }
    }

    for (final doctor in doctors) {
      batch.insert(
        'doctors',
        Map<String, dynamic>.from(doctor),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final link in doctorOrgLinks) {
      batch.insert(
        'doctor_organisations',
        Map<String, dynamic>.from(link),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final drug in drugs) {
      batch.insert(
        'drugs',
        Map<String, dynamic>.from(drug),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final material in materials) {
      final m = Map<String, dynamic>.from(material);
      batch.insert(
        'drug_materials',
        m,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final visit in visits) {
      final v = Map<String, dynamic>.from(visit);
      v['is_synced'] = 1;
      batch.insert('visits', v, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final pv in plannedVisits) {
      batch.insert(
        'planned_visits',
        Map<String, dynamic>.from(pv),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final dt in dayTypes) {
      batch.insert(
        'day_types',
        Map<String, dynamic>.from(dt),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final m in managers) {
      batch.insert(
        'managers',
        Map<String, dynamic>.from(m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _applyPendingOrgEdits(db);
    _notifyChanged([
      'organisations',
      'doctors',
      'doctor_organisations',
      'drugs',
      'drug_materials',
      'visits',
      'planned_visits',
      'day_types',
      'managers',
      if (dailyStats != null) 'cached_stats',
    ]);

    if (dailyStats != null) {
      await setCachedStat('daily_stats', dailyStats);
    }
  }

  /// Re-applies queued local organisation edits (pending_org_updates) on top
  /// of freshly pulled server rows, so an offline edit stays visible in the UI
  /// until it is pushed. Server data wins for every org without a pending edit.
  Future<void> _applyPendingOrgEdits(DatabaseExecutor executor) async {
    final pending = await executor.query('pending_org_updates');
    for (final row in pending) {
      final orgId = row['org_id'];
      if (orgId == null) continue;
      await executor.update(
        'organisations',
        {
          'name': row['name'],
          'address': row['address'],
          if (row['phone'] != null) 'phone': row['phone'],
          if (row['city'] != null) 'city': row['city'],
          if (row['district'] != null) 'district': row['district'],
          if (row['inn'] != null) 'inn': row['inn'],
          if (row['category'] != null) 'category': row['category'],
          if (row['responsible'] != null) 'responsible': row['responsible'],
          if (row['latitude'] != null) 'latitude': row['latitude'],
          if (row['longitude'] != null) 'longitude': row['longitude'],
        },
        where: 'id = ?',
        whereArgs: [orgId],
      );
    }
  }

  // ── Planned Visits ────────────────────────────────────────────────────────

  Future<void> upsertPlannedVisits(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final row in rows) {
      final r = Map<String, dynamic>.from(row);
      // Server plan rows often omit doctor/format fields. Because remote_id is
      // UNIQUE, ConflictAlgorithm.replace would otherwise delete the local row
      // (with its doctor_id/doctor_name/visit_format) and reinsert a stripped
      // one — surfacing a doctorless / wrong-type plan card. Preserve those
      // fields from the existing row when the incoming payload lacks them.
      final remoteId = (r['remote_id'] as num?)?.toInt();
      if (remoteId != null) {
        final existing = await db.query(
          'planned_visits',
          columns: ['doctor_id', 'doctor_name', 'visit_format'],
          where: 'remote_id = ?',
          whereArgs: [remoteId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final prev = existing.first;
          if ((r['doctor_id'] == null) && prev['doctor_id'] != null) {
            r['doctor_id'] = prev['doctor_id'];
          }
          if (('${r['doctor_name'] ?? ''}'.trim().isEmpty) &&
              '${prev['doctor_name'] ?? ''}'.trim().isNotEmpty) {
            r['doctor_name'] = prev['doctor_name'];
          }
          if (('${r['visit_format'] ?? ''}'.trim().isEmpty) &&
              '${prev['visit_format'] ?? ''}'.trim().isNotEmpty) {
            r['visit_format'] = prev['visit_format'];
          }
        }
      }
      batch.insert(
        'planned_visits',
        r,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notifyChanged(['planned_visits']);
  }

  /// Reconciles server-origin planned visits with the authoritative set from
  /// the API: deletes local rows that HAVE a remote_id but are no longer
  /// returned by the server (e.g. plan deleted/expired server-side). Rows
  /// without a remote_id are locally-created and never deleted here.
  /// Pass the full set of remote ids the server currently returns (may be
  /// empty — then all stale server rows are removed).
  Future<void> reconcileServerPlannedVisits(Set<int> serverRemoteIds) async {
    final localServerRows = await db.query(
      'planned_visits',
      columns: ['remote_id'],
      where: 'remote_id IS NOT NULL',
    );
    final toDelete = <int>[];
    for (final row in localServerRows) {
      final rid = (row['remote_id'] as num?)?.toInt();
      if (rid != null && !serverRemoteIds.contains(rid)) toDelete.add(rid);
    }
    if (toDelete.isEmpty) return;
    final batch = db.batch();
    for (final rid in toDelete) {
      batch.delete('planned_visits', where: 'remote_id = ?', whereArgs: [rid]);
    }
    await batch.commit(noResult: true);
    _notifyChanged(['planned_visits']);
  }

  Future<List<Map<String, dynamic>>> getPlannedVisits({
    bool? completedOnly,
  }) async {
    String where = '';
    if (completedOnly == true) where = "WHERE pv.status = 'completed'";
    if (completedOnly == false) where = "WHERE pv.status != 'completed'";
    // JOIN with organisations to enrich city/district when not present in planned_visits.
    return db.rawQuery('''
      SELECT
        pv.id, pv.remote_id, pv.org_id, pv.org_name, pv.org_type,
        pv.doctor_id, pv.doctor_name, pv.assigned_by,
        pv.visit_date, pv.status, pv.comment, pv.raw_json, pv.visit_format,
        COALESCE(NULLIF(TRIM(COALESCE(pv.city, '')), ''), o.city, '') AS city,
        COALESCE(NULLIF(TRIM(COALESCE(pv.district, '')), ''), o.district, '') AS district
      FROM planned_visits pv
      LEFT JOIN organisations o ON pv.org_id = o.id
      $where
      ORDER BY pv.visit_date DESC
    ''');
  }

  Future<void> clearPlannedVisits() async {
    await db.delete('planned_visits');
    _notifyChanged(['planned_visits']);
  }

  /// Inserts a locally-created planned visit row. Returns its local autoincrement id.
  Future<int> insertLocalPlannedVisit(Map<String, dynamic> row) async {
    final id = await db.insert(
      'planned_visits',
      Map<String, dynamic>.from(row),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged(['planned_visits']);
    return id;
  }

  /// Stamps a server-assigned [remoteId] onto a locally-created planned visit row.
  Future<void> setPlannedVisitRemoteId({
    required int localId,
    required int remoteId,
    Map<String, dynamic>? rawJson,
  }) async {
    final values = <String, dynamic>{'remote_id': remoteId};
    if (rawJson != null) values['raw_json'] = jsonEncode(rawJson);
    await db.update(
      'planned_visits',
      values,
      where: 'id = ?',
      whereArgs: [localId],
    );
    _notifyChanged(['planned_visits']);
  }

  Future<void> deleteLocalPlannedVisit(int localId) async {
    await db.delete('planned_visits', where: 'id = ?', whereArgs: [localId]);
    _notifyChanged(['planned_visits']);
  }

  // ── Pending planned visits queue ──────────────────────────────────────────

  Future<void> enqueuePendingPlan({
    required int localPlanId,
    required int orgId,
    required String orgType,
    required List<int> doctorIds,
    required int visitFormatId,
    required DateTime visitDate,
    String? comment,
  }) async {
    final isoDate = _isoYmd(visitDate);
    await db.insert('pending_plans', {
      'local_plan_id': localPlanId,
      'org_id': orgId,
      'org_type': orgType,
      'doctor_ids_json': jsonEncode(doctorIds),
      'visit_format_id': visitFormatId,
      'start_date': isoDate,
      'end_date': isoDate,
      'comment': comment ?? '',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged(['pending_plans']);
  }

  Future<List<Map<String, dynamic>>> getPendingPlans() async {
    return db.query('pending_plans', orderBy: 'id ASC');
  }

  Future<void> deletePendingPlan(int id) async {
    await db.delete('pending_plans', where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['pending_plans']);
  }

  Future<int> pendingPlansCount() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM pending_plans');
    return (rows.first['c'] as int?) ?? 0;
  }

  static String _isoYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  // ── Day Types ─────────────────────────────────────────────────────────────

  Future<void> upsertDayTypes(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'day_types',
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notifyChanged(['day_types']);
  }

  Future<List<Map<String, dynamic>>> getDayTypes() async {
    return db.query('day_types', orderBy: 'id');
  }

  // ── Visit formats (cached from /api/visits/formats) ───────────────────────

  Future<void> upsertVisitFormats(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'visit_formats',
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notifyChanged(['visit_formats']);
  }

  Future<List<Map<String, dynamic>>> getVisitFormats() async {
    return db.query('visit_formats', orderBy: 'id');
  }

  // ── Managers ──────────────────────────────────────────────────────────────

  Future<void> upsertManagers(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'managers',
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notifyChanged(['managers']);
  }

  Future<List<Map<String, dynamic>>> getManagers() async {
    return db.query('managers', orderBy: 'full_name');
  }

  // ── Cached Stats ──────────────────────────────────────────────────────────

  Future<void> setCachedStat(String key, Map<String, dynamic> value) async {
    await db.insert('cached_stats', {
      'key': key,
      'value': jsonEncode(value),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChanged(['cached_stats']);
  }

  Future<Map<String, dynamic>?> getCachedStat(String key) async {
    final rows = await db.query(
      'cached_stats',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Favourite Organisations ───────────────────────────────────────────────

  Future<void> updateOrgFavorite(int orgId, bool isFavorite) async {
    await db.update(
      'organisations',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [orgId],
    );
    _notifyChanged(['organisations']);
  }

  Future<void> clearOrgFavorites() async {
    await db.update('organisations', {'is_favorite': 0});
    _notifyChanged(['organisations']);
  }

  Future<List<Map<String, dynamic>>> getFavoriteOrgs({String? type}) async {
    final conditions = ['is_favorite = 1'];
    final args = <dynamic>[];
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    return db.rawQuery(
      'SELECT * FROM organisations WHERE ${conditions.join(' AND ')} ORDER BY name',
      args,
    );
  }

  Future<void> replaceRemoteSnapshotPreservingUnsynced({
    required List<Map> orgs,
    required List<Map> doctors,
    List<Map> doctorOrgLinks = const [],
    bool replaceDoctors = true,
    required List<Map> drugs,
    required List<Map> materials,
    required List<Map> visits,
    List<Map> plannedVisits = const [],
    List<Map> favOrgIds = const [],
    List<Map> managers = const [],
    List<Map> dayTypes = const [],
    Map<String, dynamic>? dailyStats,
  }) async {
    final unsynced = await getVisits(unsyncedOnly: true);
    // Offline-created orgs/doctors (negative id, awaiting push in
    // pending_organizations/pending_doctors) live only as mirror rows in
    // these tables — capture them before the wipe so they don't vanish from
    // the UI until they're actually pushed.
    final unsyncedOrgs = await db.query(
      'organisations',
      where: 'id < 0',
    );
    final unsyncedDoctors = replaceDoctors
        ? await db.query('doctors', where: 'id < 0')
        : const <Map<String, dynamic>>[];

    await db.transaction((txn) async {
      await txn.delete('organisations');
      if (replaceDoctors) {
        await txn.delete('doctors');
        await txn.delete('doctor_organisations');
      }
      await txn.delete('drugs');
      await txn.delete('drug_materials');
      await txn.delete('visits');
      await txn.delete('planned_visits');
      await txn.delete('day_types');
      await txn.delete('managers');

      for (final org in orgs) {
        await txn.insert(
          'organisations',
          Map<String, dynamic>.from(org),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await _applyPendingOrgEdits(txn);

      for (final org in unsyncedOrgs) {
        await txn.insert(
          'organisations',
          Map<String, dynamic>.from(org),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final favIds = favOrgIds.map((e) => e['id']).whereType<int>().toSet();
      for (final id in favIds) {
        await txn.rawUpdate(
          'UPDATE organisations SET is_favorite = 1 WHERE id = ?',
          [id],
        );
      }

      for (final doctor in doctors) {
        await txn.insert(
          'doctors',
          Map<String, dynamic>.from(doctor),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (replaceDoctors) {
        for (final doctor in unsyncedDoctors) {
          await txn.insert(
            'doctors',
            Map<String, dynamic>.from(doctor),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      for (final link in doctorOrgLinks) {
        await txn.insert(
          'doctor_organisations',
          Map<String, dynamic>.from(link),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final drug in drugs) {
        await txn.insert(
          'drugs',
          Map<String, dynamic>.from(drug),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final material in materials) {
        await txn.insert(
          'drug_materials',
          Map<String, dynamic>.from(material),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final visit in visits) {
        final v = Map<String, dynamic>.from(visit);
        v['is_synced'] = 1;
        await txn.insert(
          'visits',
          v,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in unsynced) {
        final v = Map<String, dynamic>.from(row);
        v.remove('id');
        v['is_synced'] = 0;
        await txn.insert('visits', v);
      }

      for (final pv in plannedVisits) {
        await txn.insert(
          'planned_visits',
          Map<String, dynamic>.from(pv),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final dt in dayTypes) {
        await txn.insert(
          'day_types',
          Map<String, dynamic>.from(dt),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final m in managers) {
        await txn.insert(
          'managers',
          Map<String, dynamic>.from(m),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    if (dailyStats != null) {
      await setCachedStat('daily_stats', dailyStats);
    }
    _notifyChanged([
      'organisations',
      if (replaceDoctors) 'doctors',
      if (replaceDoctors) 'doctor_organisations',
      'drugs',
      'drug_materials',
      'visits',
      'planned_visits',
      'day_types',
      'managers',
      if (dailyStats != null) 'cached_stats',
    ]);
  }

  // ── isEmpty ───────────────────────────────────────────────────────────────

  Future<bool> isEmpty() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM organisations',
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count == 0;
  }

  Future<void> setCurrentUserOwner({
    required int userId,
    required String login,
    required String role,
  }) async {
    await setSyncMeta(_ownerUserIdKey, '$userId');
    await setSyncMeta(_ownerLoginKey, login);
    await setSyncMeta(_ownerRoleKey, role);
  }

  Future<({int? userId, String? login, String? role})>
  getCurrentUserOwner() async {
    final userIdRaw = await getSyncMeta(_ownerUserIdKey);
    final login = await getSyncMeta(_ownerLoginKey);
    final role = await getSyncMeta(_ownerRoleKey);
    return (userId: int.tryParse(userIdRaw ?? ''), login: login, role: role);
  }

  Future<bool> matchesCurrentUserOwner({required String login}) async {
    final owner = await getCurrentUserOwner();
    return owner.login != null && owner.login == login;
  }

  Future<bool> hasUsableOfflineSessionForLogin(String login) async {
    if (!await matchesCurrentUserOwner(login: login)) return false;
    return !(await isEmpty());
  }

  Future<void> clearCurrentUserOwner() async {
    await db.delete(
      'sync_meta',
      where: 'key IN (?, ?, ?)',
      whereArgs: [_ownerUserIdKey, _ownerLoginKey, _ownerRoleKey],
    );
  }

  Future<void> clearUserScopedData() async {
    await db.transaction((txn) async {
      await txn.update(
        'organisations',
        {'is_favorite': 0},
        where: 'is_favorite = ?',
        whereArgs: [1],
      );
      await txn.update(
        'doctors',
        {'is_favorite': 0},
        where: 'is_favorite = ?',
        whereArgs: [1],
      );
      await txn.update('drugs', {'documents_count': 0});
      for (final table in const [
        'drug_materials',
        'visits',
        'planned_visits',
        'day_types',
        'managers',
        'cached_stats',
        'pending_feedback',
        'pending_favorites',
        'pending_doctors',
        'pending_org_updates',
      ]) {
        await txn.delete(table);
      }
      await txn.delete(
        'sync_meta',
        where: 'key IN (?, ?, ?, ?, ?, ?, ?)',
        whereArgs: [
          _ownerUserIdKey,
          _ownerLoginKey,
          _ownerRoleKey,
          'last_pull_at',
          'last_delta_pull_at',
          'last_app_activity_at',
          'last_push_at',
        ],
      );
    });
    _notifyChanged([
      'organisations',
      'doctors',
      'drugs',
      'drug_materials',
      'visits',
      'planned_visits',
      'day_types',
      'managers',
      'cached_stats',
      'pending_feedback',
      'pending_favorites',
      'pending_doctors',
      'pending_org_updates',
    ]);
  }

  // ── Organisations ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrganisations({
    String? type,
    String? query,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }

    if (query != null && query.isNotEmpty) {
      conditions.add('(name LIKE ? OR address LIKE ? OR city LIKE ?)');
      final like = '%$query%';
      args.addAll([like, like, like]);
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery(
      'SELECT * FROM organisations $where ORDER BY name',
      args,
    );
  }

  Future<Map<String, dynamic>?> getOrganisationById(int id) async {
    final rows = await db.query(
      'organisations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateOrganisation({
    required int id,
    String? name,
    String? address,
    String? city,
    String? district,
    String? inn,
    String? category,
    String? responsible,
    String? phone,
    double? latitude,
    double? longitude,
    String? updatedAt,
    String? rawJson,
  }) async {
    await db.update(
      'organisations',
      {
        'name': ?name,
        'address': ?address,
        'city': ?city,
        'district': ?district,
        'inn': ?inn,
        'category': ?category,
        'responsible': ?responsible,
        'phone': ?phone,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'updated_at': ?updatedAt,
        'raw_json': ?rawJson,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged(['organisations']);
  }

  // ── Doctors ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDoctors({
    int? orgId,
    String? query,
    bool includeGlobalFallback = true,
  }) async {
    String queryFilter = '';
    final args = <dynamic>[];

    if (query != null && query.isNotEmpty) {
      queryFilter = ' AND (full_name LIKE ? OR specialty LIKE ?)';
      final like = '%$query%';
      args.addAll([like, like]);
    }

    if (orgId != null) {
      final linked = await db.rawQuery(
        '''SELECT DISTINCT d.* FROM doctors d
           INNER JOIN doctor_organisations rel ON rel.doctor_id = d.id
           WHERE rel.organisation_id = ?$queryFilter
           ORDER BY d.full_name''',
        [orgId, ...args],
      );
      if (linked.isNotEmpty) return linked;

      // Primary: doctors explicitly linked to this org
      final orgSpecific = await db.rawQuery(
        'SELECT * FROM doctors WHERE organisation_id = ?$queryFilter ORDER BY full_name',
        [orgId, ...args],
      );
      if (orgSpecific.isNotEmpty) return orgSpecific;

      // Fallback 1: doctors previously used in visits to this org
      final fromVisits = await db.rawQuery(
        '''SELECT DISTINCT d.* FROM doctors d
           INNER JOIN visits v ON v.doctor_id = d.id
           WHERE v.org_id = ? AND d.id IS NOT NULL$queryFilter
           ORDER BY d.full_name''',
        [orgId, ...args],
      );
      if (fromVisits.isNotEmpty) return fromVisits;

      if (!includeGlobalFallback) return const <Map<String, dynamic>>[];

      // Fallback 2: global doctors (organisation_id = 0 or NULL) — synced without org association
      return db.rawQuery(
        'SELECT * FROM doctors WHERE (organisation_id = 0 OR organisation_id IS NULL)$queryFilter ORDER BY full_name',
        args,
      );
    }

    final where = queryFilter.isEmpty
        ? ''
        : 'WHERE ${queryFilter.substring(5)}';
    return db.rawQuery('SELECT * FROM doctors $where ORDER BY full_name', args);
  }

  Future<int> insertDoctor(Map<String, dynamic> doctor) async {
    final id = await db.insert(
      'doctors',
      doctor,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged(['doctors']);
    return id;
  }

  Future<void> upsertDoctors(List<Map<String, dynamic>> doctors) async {
    if (doctors.isEmpty) return;
    final batch = db.batch();
    for (final row in doctors) {
      final id = row['id'];
      if (row['is_deleted'] == true || row['is_deleted'] == 1) {
        if (id != null) {
          batch.delete('doctors', where: 'id = ?', whereArgs: [id]);
        }
      } else {
        final r = Map<String, dynamic>.from(row)..remove('is_deleted');
        batch.insert(
          'doctors',
          r,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
    _notifyChanged(['doctors']);
  }

  Future<void> upsertDoctorOrganisationLinks(
    List<Map<String, dynamic>> links,
  ) async {
    if (links.isEmpty) return;
    final batch = db.batch();
    for (final link in links) {
      batch.insert(
        'doctor_organisations',
        Map<String, dynamic>.from(link),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notifyChanged(['doctor_organisations']);
  }

  Future<int> updateDoctorFavorite(int doctorId, bool isFavorite) async {
    final count = await db.update(
      'doctors',
      {
        'is_favorite': isFavorite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [doctorId],
    );
    _notifyChanged(['doctors']);
    return count;
  }

  Future<List<Map<String, dynamic>>> getFavoriteDoctors() {
    return db.rawQuery(
      'SELECT * FROM doctors WHERE is_favorite = 1 ORDER BY full_name',
    );
  }

  Future<Map<String, dynamic>?> getDoctorById(int id) async {
    final rows = await db.query(
      'doctors',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Resolves the organisation a doctor belongs to, even when the doctor row's
  /// own `organisation_id` column is 0/NULL (common for globally-synced doctors).
  /// Falls back to the `doctor_organisations` link table, then to the most
  /// recent visit's org. Returns null when no association can be found.
  Future<int?> getPrimaryOrgIdForDoctor(int doctorId) async {
    final direct = await db.query(
      'doctors',
      columns: ['organisation_id'],
      where: 'id = ?',
      whereArgs: [doctorId],
      limit: 1,
    );
    final directOrg = (direct.isEmpty ? null : direct.first['organisation_id'])
        as num?;
    if (directOrg != null && directOrg.toInt() > 0) return directOrg.toInt();

    final linked = await db.rawQuery(
      'SELECT organisation_id FROM doctor_organisations WHERE doctor_id = ? LIMIT 1',
      [doctorId],
    );
    final linkedOrg = (linked.isEmpty ? null : linked.first['organisation_id'])
        as num?;
    if (linkedOrg != null && linkedOrg.toInt() > 0) return linkedOrg.toInt();

    final fromVisit = await db.rawQuery(
      'SELECT org_id FROM visits WHERE doctor_id = ? AND org_id IS NOT NULL '
      'ORDER BY created_at DESC LIMIT 1',
      [doctorId],
    );
    final visitOrg = (fromVisit.isEmpty ? null : fromVisit.first['org_id'])
        as num?;
    if (visitOrg != null && visitOrg.toInt() > 0) return visitOrg.toInt();

    return null;
  }

  Future<int> getFavoriteDoctorsCount() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM doctors WHERE is_favorite = 1',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> clearDoctorFavorites() async {
    await db.update('doctors', {
      'is_favorite': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
    _notifyChanged(['doctors']);
  }

  // ── Drugs ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDrugs({
    String? query,
    bool onlyWithPositivePrice = true,
    bool onlyWithDocuments = false,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (onlyWithPositivePrice) {
      conditions.add('price > 0');
    }

    if (onlyWithDocuments) {
      conditions.add('documents_count > 0');
    }

    if (query != null && query.isNotEmpty) {
      conditions.add('(name LIKE ? OR manufacturer LIKE ?)');
      final like = '%$query%';
      args.addAll([like, like]);
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('SELECT * FROM drugs $where ORDER BY name', args);
  }

  Future<void> upsertDrugs(List<Map<String, dynamic>> drugs) async {
    if (drugs.isEmpty) return;
    await db.transaction((txn) async {
      for (final row in drugs) {
        final r = Map<String, dynamic>.from(row);
        final id = r['id'];
        if (id == null) continue;

        // Preserve current_stock_id / binding_drug_id if the incoming row
        // doesn't have them (delta-sync rows don't include price-list fields).
        if (!r.containsKey('current_stock_id') ||
            r['current_stock_id'] == null) {
          r.remove('current_stock_id');
        }
        if (!r.containsKey('binding_drug_id') || r['binding_drug_id'] == null) {
          r.remove('binding_drug_id');
        }
        for (final stockKey in ['stock', 'main_stock', 'remains_stock']) {
          if (!r.containsKey(stockKey) || r[stockKey] == null) {
            r.remove(stockKey);
          }
        }
        // Catalogue (bindings) rows carry no price; never overwrite an existing
        // price-list price with a missing/zero value.
        final priceVal = r['price'];
        final priceNum = priceVal is num
            ? priceVal.toDouble()
            : double.tryParse('${priceVal ?? ''}');
        if (priceNum == null || priceNum <= 0) {
          r.remove('price');
        }
        final documentsCount = r['documents_count'];
        final documentsCountValue = documentsCount is num
            ? documentsCount.toInt()
            : int.tryParse('${documentsCount ?? ''}');
        if (!r.containsKey('documents_count') ||
            documentsCountValue == null ||
            documentsCountValue <= 0) {
          r.remove('documents_count');
        }

        final existing = await txn.query(
          'drugs',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (existing.isEmpty) {
          await txn.insert(
            'drugs',
            r,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          await txn.update('drugs', r, where: 'id = ?', whereArgs: [id]);
        }
      }
    });
    _notifyChanged(['drugs']);
  }

  Future<void> upsertDrugMaterials(List<Map<String, dynamic>> materials) async {
    if (materials.isEmpty) return;
    final drugIds = materials
        .map((m) => m['drug_id'])
        .whereType<int>()
        .toSet()
        .toList();
    await db.transaction((txn) async {
      // Preserve cached_path values keyed by (drug_id, local_path)
      final cachedPaths = <String, String>{};
      for (final id in drugIds) {
        final existing = await txn.query(
          'drug_materials',
          columns: ['drug_id', 'local_path', 'cached_path'],
          where: 'drug_id = ?',
          whereArgs: [id],
        );
        for (final row in existing) {
          final cp = row['cached_path'] as String?;
          if (cp != null && cp.isNotEmpty) {
            final key = '${row['drug_id']}:${row['local_path']}';
            cachedPaths[key] = cp;
          }
        }
        await txn.delete(
          'drug_materials',
          where: 'drug_id = ?',
          whereArgs: [id],
        );
      }
      for (final row in materials) {
        final r = Map<String, dynamic>.from(row)..remove('id');
        final key = '${r['drug_id']}:${r['local_path']}';
        if (cachedPaths.containsKey(key)) {
          r['cached_path'] = cachedPaths[key];
        }
        await txn.insert('drug_materials', r);
      }
    });
    _notifyChanged(['drug_materials']);
  }

  Future<void> updateMaterialCachedPath(int id, String localPath) async {
    await db.update(
      'drug_materials',
      {'cached_path': localPath},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged(['drug_materials']);
  }

  Future<List<Map<String, dynamic>>> getMaterialsToCache() async {
    return db.query(
      'drug_materials',
      where:
          "local_path IS NOT NULL AND local_path != '' AND (cached_path IS NULL OR cached_path = '')",
    );
  }

  Future<void> updateDrugDocumentsCount(int drugId, int count) async {
    await db.update(
      'drugs',
      {'documents_count': count},
      where: 'id = ?',
      whereArgs: [drugId],
    );
    _notifyChanged(['drugs']);
  }

  /// Clears documents_count for every drug. Called before re-applying the fresh
  /// counts from /api/Documents so drugs that no longer have any documents stop
  /// appearing in the knowledge base (which filters on documents_count > 0).
  Future<void> resetAllDrugDocumentsCount() async {
    await db.update('drugs', {'documents_count': 0});
    _notifyChanged(['drugs']);
  }

  Future<void> updateDrugName(int drugId, String name) async {
    await db.update(
      'drugs',
      {'name': name},
      where: 'id = ?',
      whereArgs: [drugId],
    );
    _notifyChanged(['drugs']);
  }

  Future<void> upsertOrganisations(List<Map<String, dynamic>> orgs) async {
    if (orgs.isEmpty) return;
    final batch = db.batch();
    for (final row in orgs) {
      final id = row['id'];
      if (row['is_deleted'] == true || row['is_deleted'] == 1) {
        if (id != null) {
          batch.delete('organisations', where: 'id = ?', whereArgs: [id]);
        }
      } else {
        final r = Map<String, dynamic>.from(row)..remove('is_deleted');
        batch.insert(
          'organisations',
          r,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
    await _applyPendingOrgEdits(db);
    _notifyChanged(['organisations']);
  }

  // ── Drug Materials ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDrugMaterials(int drugId) async {
    return db.query(
      'drug_materials',
      where: 'drug_id = ?',
      whereArgs: [drugId],
      orderBy: 'id',
    );
  }

  // ── Visits ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getVisits({
    bool? unsyncedOnly,
    bool dueForRetryOnly = false,
  }) async {
    if (unsyncedOnly == true) {
      // When [dueForRetryOnly] is set, skip visits whose backoff window has not
      // elapsed yet (next_retry_at in the future) so the push loop does not
      // hammer the server on every reconcile.
      // Visits marked sync_failed are parked: they stay in the DB but are
      // excluded from automatic pushes until the user retries them manually.
      if (dueForRetryOnly) {
        final nowIso = DateTime.now().toIso8601String();
        return db.query(
          'visits',
          where:
              'is_synced = ? AND (sync_failed IS NULL OR sync_failed = 0) '
              'AND (next_retry_at IS NULL OR next_retry_at <= ?)',
          whereArgs: [0, nowIso],
          orderBy: 'created_at DESC',
        );
      }
      return db.query(
        'visits',
        where: 'is_synced = ? AND (sync_failed IS NULL OR sync_failed = 0)',
        whereArgs: [0],
        orderBy: 'created_at DESC',
      );
    }
    return db.query('visits', orderBy: 'created_at DESC');
  }

  Future<Map<int, int>> getVisitCountsByDoctorIds(List<int> doctorIds) async {
    if (doctorIds.isEmpty) return const <int, int>{};
    final placeholders = doctorIds.map((_) => '?').join(', ');
    final rows = await db.rawQuery('''
      SELECT doctor_id, COUNT(*) AS cnt
      FROM visits
      WHERE doctor_id IS NOT NULL AND doctor_id IN ($placeholders)
      GROUP BY doctor_id
      ''', doctorIds);

    final result = <int, int>{};
    for (final row in rows) {
      final id = (row['doctor_id'] as num?)?.toInt();
      final cnt = (row['cnt'] as num?)?.toInt() ?? 0;
      if (id != null) {
        result[id] = cnt;
      }
    }
    return result;
  }

  Future<int> insertVisit(Map<String, dynamic> visit) async {
    final v = Map<String, dynamic>.from(visit);
    v['is_synced'] = 0;
    final id = await db.insert(
      'visits',
      v,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged(['visits']);
    return id;
  }

  Future<void> deleteVisit(int id) async {
    await db.delete('visits', where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['visits']);
  }

  /// Parks a visit the push loop gave up on (server rejected it, or all retry
  /// attempts were exhausted). The row is kept so field data is never lost:
  /// it disappears from the automatic push queue and shows up in the sync
  /// screen, where the user can retry or explicitly delete it.
  Future<void> markVisitPushFailedPermanently(int id) async {
    await db.update(
      'visits',
      {'sync_failed': 1, 'next_retry_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged(['visits']);
  }

  /// Returns a parked visit to the push queue with a clean retry slate.
  Future<void> retryFailedVisit(int id) async {
    await db.update(
      'visits',
      {'sync_failed': 0, 'push_attempts': 0, 'next_retry_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged(['visits']);
  }

  Future<List<Map<String, dynamic>>> getFailedVisits() async {
    return db.query(
      'visits',
      where: 'sync_failed = 1',
      orderBy: 'created_at DESC',
    );
  }

  /// One-off migration for visits created before the talked_about_drugs payload
  /// format was fixed. Older builds stored drugs as `{drug_name, status:"..."}`,
  /// which the server rejects (HTTP 400 "не указан статус"), so those visits got
  /// parked and never reached the CRM. This rewrites their raw_json to the
  /// server format `{drug_id, status_id, ...}` and re-queues them for push.
  /// Returns the number of visits repaired.
  Future<int> repairLegacyVisitDrugPayloads() async {
    // Map known drug names → binding id, to recover drug_id for legacy rows.
    final drugRows = await db.query('drugs', columns: ['id', 'name']);
    final nameToId = <String, int>{};
    for (final r in drugRows) {
      final id = (r['id'] as num?)?.toInt();
      final name = (r['name'] as String?)?.trim().toLowerCase();
      if (id != null && name != null && name.isNotEmpty) {
        nameToId[name] = id;
      }
    }

    int statusIdFor(String? legacy) => switch (legacy) {
      'familiar_prescribes' => 4,
      'familiar_not_prescribes' => 5,
      'not_familiar' => 6,
      'other' => 2,
      _ => 2,
    };

    List<dynamic>? convert(dynamic list) {
      if (list is! List) return null;
      var changed = false;
      final out = <dynamic>[];
      for (final e in list) {
        if (e is! Map) {
          out.add(e);
          continue;
        }
        final m = Map<String, dynamic>.from(e);
        // Already in the new format — leave it.
        final hasStatusId = m['status_id'] != null;
        final hasDrugId = m['drug_id'] != null;
        if (hasStatusId && hasDrugId) {
          out.add(m);
          continue;
        }
        if (!hasStatusId && m['status'] is String) {
          m['status_id'] = statusIdFor(m['status'] as String?);
          changed = true;
        }
        if (!hasDrugId) {
          final name = (m['drug_name'] as String?)?.trim().toLowerCase();
          final id = name == null ? null : nameToId[name];
          if (id != null) {
            m['drug_id'] = id;
            changed = true;
          }
        }
        m.putIfAbsent('ball', () => null);
        m.putIfAbsent('comment', () => '');
        m.putIfAbsent('document_ids', () => const <int>[]);
        out.add(m);
      }
      return changed ? out : null;
    }

    // Candidates: unsynced visits (parked or not) that have a raw_json.
    final rows = await db.query(
      'visits',
      where: 'is_synced = 0 AND raw_json IS NOT NULL AND raw_json != ?',
      whereArgs: [''],
    );

    var repaired = 0;
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final rawJson = row['raw_json'] as String?;
      if (id == null || rawJson == null || rawJson.isEmpty) continue;
      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is! Map) continue;
        parsed = Map<String, dynamic>.from(decoded);
      } catch (_) {
        continue;
      }

      var dirty = false;
      final talked = convert(parsed['talked_about_drugs']);
      if (talked != null) {
        parsed['talked_about_drugs'] = talked;
        dirty = true;
      }
      final presentations = convert(parsed['presentations']);
      if (presentations != null) {
        parsed['presentations'] = presentations;
        dirty = true;
      }
      if (!dirty) continue;

      await db.update(
        'visits',
        {
          'raw_json': jsonEncode(parsed),
          // Re-queue: clear the parked flag and backoff so the push loop retries.
          'sync_failed': 0,
          'push_attempts': 0,
          'next_retry_at': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      repaired++;
    }
    if (repaired > 0) _notifyChanged(['visits']);
    return repaired;
  }

  Future<int> failedVisitsCount() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM visits WHERE sync_failed = 1',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> deleteLegacyTestVisits() async {
    final count = await db.delete(
      'visits',
      where:
          "org_name = ? OR notes LIKE ? OR (visit_type = ? AND doctor_id IS NULL AND remote_id IS NULL)",
      whereArgs: ['Тестовая организация', 'Офлайн визит %', 'lpu'],
    );
    if (count > 0) _notifyChanged(['visits']);
    return count;
  }

  Future<void> updateVisitStatus(int id, String status, {String? notes}) async {
    final values = <String, dynamic>{
      'status': status,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) values['notes'] = notes;

    await db.update('visits', values, where: 'id = ?', whereArgs: [id]);
    _notifyChanged(['visits']);
  }

  Future<void> updateVisitStatusByRemoteId(
    int remoteId,
    String status, {
    String? notes,
  }) async {
    final values = <String, dynamic>{
      'status': status,
      'is_synced': 1,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) values['notes'] = notes;

    await db.update(
      'visits',
      values,
      where: 'remote_id = ?',
      whereArgs: [remoteId],
    );
    _notifyChanged(['visits']);
  }

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = ids.map((_) => '?').join(', ');
    // Clear retry bookkeeping on success so the row is fully resolved.
    await db.rawUpdate(
      'UPDATE visits SET is_synced = 1, push_attempts = 0, next_retry_at = NULL '
      'WHERE id IN ($placeholders)',
      ids,
    );
    _notifyChanged(['visits']);
  }

  /// Records a failed (transient) push attempt for a visit: increments
  /// [push_attempts] and schedules [next_retry_at] using an exponential-ish
  /// backoff (1m, 5m, 30m, then 60m). Returns the new attempt count.
  Future<int> recordVisitPushFailure(int visitId) async {
    final rows = await db.query(
      'visits',
      columns: ['push_attempts'],
      where: 'id = ?',
      whereArgs: [visitId],
      limit: 1,
    );
    final current = rows.isEmpty
        ? 0
        : ((rows.first['push_attempts'] as num?)?.toInt() ?? 0);
    final attempts = current + 1;
    final backoff = _retryBackoffFor(attempts);
    final nextRetry = DateTime.now().add(backoff).toIso8601String();
    await db.update(
      'visits',
      {'push_attempts': attempts, 'next_retry_at': nextRetry},
      where: 'id = ?',
      whereArgs: [visitId],
    );
    _notifyChanged(['visits']);
    return attempts;
  }

  static Duration _retryBackoffFor(int attempts) {
    switch (attempts) {
      case 1:
        return const Duration(minutes: 1);
      case 2:
        return const Duration(minutes: 5);
      case 3:
        return const Duration(minutes: 30);
      default:
        return const Duration(minutes: 60);
    }
  }

  Future<void> setVisitPushPayload({
    required int visitId,
    String? requestJson,
    String? responseJson,
  }) async {
    await db.update(
      'visits',
      {
        'last_push_request_json': ?requestJson,
        'last_push_response_json': ?responseJson,
      },
      where: 'id = ?',
      whereArgs: [visitId],
    );
    _notifyChanged(['visits']);
  }

  Future<void> updateVisitRemoteId({
    required int localVisitId,
    required int remoteId,
  }) async {
    await db.update(
      'visits',
      {
        'remote_id': remoteId,
        'is_synced': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localVisitId],
    );
    _notifyChanged(['visits']);
  }

  Future<void> updateVisitRawJson({
    required int localVisitId,
    required String rawJson,
  }) async {
    await db.update(
      'visits',
      {'raw_json': rawJson, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [localVisitId],
    );
    _notifyChanged(['visits']);
  }

  Future<int> unsyncedCount() async {
    // Parked (sync_failed) visits are counted separately via
    // [failedVisitsCount] — they need user attention, not another auto-push.
    final visits = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM visits '
      'WHERE is_synced = 0 AND (sync_failed IS NULL OR sync_failed = 0)',
    );
    // Pending plan submissions also count as "ожидают отправки" so the badge
    // accurately reflects everything that still needs to reach the server.
    final plans = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM pending_plans',
    );
    return (Sqflite.firstIntValue(visits) ?? 0) +
        (Sqflite.firstIntValue(plans) ?? 0);
  }

  // ── Sync Meta ─────────────────────────────────────────────────────────────

  Future<void> setSyncMeta(String key, String value) async {
    await db.insert('sync_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSyncMeta(String key) async {
    final rows = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<int> getMaxLocalSyncId() async {
    Future<int> maxFrom(String table) async {
      final rows = await db.rawQuery('SELECT MAX(sync_id) AS m FROM $table');
      return Sqflite.firstIntValue(rows) ?? 0;
    }

    final values = await Future.wait([
      maxFrom('organisations'),
      maxFrom('doctors'),
      maxFrom('doctor_organisations'),
      maxFrom('drugs'),
    ]);
    return values.fold<int>(0, (max, value) => value > max ? value : max);
  }
}
