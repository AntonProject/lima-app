import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

// ─── LocalDatabase ────────────────────────────────────────────────────────────

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _db;

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
      version: 10,
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
        address     TEXT,
        type        TEXT,
        city        TEXT,
        region_id   INTEGER,
        district    TEXT,
        area_id     INTEGER,
        inn         TEXT,
        category    TEXT,
        responsible TEXT,
        phone       TEXT,
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
        stock            INTEGER,
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
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        temp_local_id INTEGER NOT NULL,
        org_id        INTEGER NOT NULL,
        full_name     TEXT NOT NULL,
        specialty     TEXT NOT NULL,
        phone         TEXT,
        created_at    TEXT NOT NULL
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN latitude REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN longitude REAL');
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE organisations ADD COLUMN distance_m REAL',
        );
      } catch (_) {}
    }
    if (oldVersion < 3) {
      await _ensureRawAndSyncColumns(db);
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN phone TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN district TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN inn TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE organisations ADD COLUMN category TEXT');
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE organisations ADD COLUMN responsible TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE organisations ADD COLUMN is_favorite INTEGER DEFAULT 0',
        );
      } catch (_) {}
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
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS day_types (
            id       INTEGER PRIMARY KEY,
            name     TEXT,
            raw_json TEXT
          )
        ''');
      } catch (_) {}
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
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_stats (
            key        TEXT PRIMARY KEY,
            value      TEXT,
            updated_at TEXT
          )
        ''');
      } catch (_) {}
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
      } catch (_) {}
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
      } catch (_) {}
    }
    if (oldVersion < 9) {
      await _ensureRegionColumns(db);
    }
    if (oldVersion < 10) {
      await _ensureDoctorOrganisationTable(db);
    }
  }

  Future<void> _ensureOptionalColumns() async {
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN latitude REAL');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN longitude REAL');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN distance_m REAL');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN phone TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN district TEXT');
    } catch (_) {}
    await _ensureRegionColumns(db);
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN inn TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN category TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organisations ADD COLUMN responsible TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN serial_number TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN expiry_date TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN stock INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN current_stock_id INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE drugs ADD COLUMN binding_drug_id INTEGER');
    } catch (_) {}
    await _ensureRawAndSyncColumns(db);
    await _ensureDoctorOrganisationTable(db);
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

  Future<void> _ensureRegionColumns(Database database) async {
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN region_id INTEGER',
      );
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN area_id INTEGER',
      );
    } catch (_) {}
  }

  Future<void> _ensureRawAndSyncColumns(Database database) async {
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN sync_id INTEGER',
      );
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN raw_json TEXT',
      );
    } catch (_) {}
    try {
      await database.execute('ALTER TABLE doctors ADD COLUMN sync_id INTEGER');
    } catch (_) {}
    try {
      await database.execute('ALTER TABLE doctors ADD COLUMN raw_json TEXT');
    } catch (_) {}
    try {
      await database.execute('ALTER TABLE drugs ADD COLUMN sync_id INTEGER');
    } catch (_) {}
    try {
      await database.execute('ALTER TABLE drugs ADD COLUMN raw_json TEXT');
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE drug_materials ADD COLUMN raw_json TEXT',
      );
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE organisations ADD COLUMN is_favorite INTEGER DEFAULT 0',
      );
    } catch (_) {}
    try {
      await database.execute('ALTER TABLE visits ADD COLUMN raw_json TEXT');
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN last_push_request_json TEXT',
      );
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN last_push_response_json TEXT',
      );
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE drug_materials ADD COLUMN cached_path TEXT',
      );
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE drug_materials ADD COLUMN uploaded_at TEXT',
      );
    } catch (_) {}
    try {
      await database.execute(
        'ALTER TABLE visits ADD COLUMN medical_rep_name TEXT',
      );
    } catch (_) {}
    try {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS pending_feedback (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          message     TEXT NOT NULL,
          photo_paths TEXT,
          created_at  TEXT NOT NULL
        )
      ''');
    } catch (_) {}
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
    } catch (_) {}
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
  }

  Future<List<Map<String, dynamic>>> getPendingFavorites() async {
    return db.query('pending_favorites', orderBy: 'id ASC');
  }

  Future<void> deletePendingFavorite(int id) async {
    await db.delete('pending_favorites', where: 'id = ?', whereArgs: [id]);
  }

  // ── Pending feedback queue ────────────────────────────────────────────────

  Future<void> enqueueFeedback(String message, List<String> photoPaths) async {
    await db.insert('pending_feedback', {
      'message': message,
      'photo_paths': jsonEncode(photoPaths),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingFeedback() async {
    return db.query('pending_feedback', orderBy: 'id ASC');
  }

  Future<void> deletePendingFeedback(int id) async {
    await db.delete('pending_feedback', where: 'id = ?', whereArgs: [id]);
  }

  // ── Pending doctors queue ─────────────────────────────────────────────────

  /// Сохраняет запрос на создание врача в очередь.
  /// [tempLocalId] — отрицательный id, под которым врач уже вставлен в таблицу doctors.
  Future<void> enqueuePendingDoctor({
    required int tempLocalId,
    required int orgId,
    required String fullName,
    required String specialty,
    String? phone,
  }) async {
    await db.insert('pending_doctors', {
      'temp_local_id': tempLocalId,
      'org_id': orgId,
      'full_name': fullName,
      'specialty': specialty,
      'phone': phone,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingDoctors() async {
    return db.query('pending_doctors', orderBy: 'id ASC');
  }

  Future<void> deletePendingDoctor(int id) async {
    await db.delete('pending_doctors', where: 'id = ?', whereArgs: [id]);
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
  }

  Future<List<Map<String, dynamic>>> getPendingOrgUpdates() async {
    return db.query('pending_org_updates', orderBy: 'id ASC');
  }

  Future<void> deletePendingOrgUpdate(int id) async {
    await db.delete('pending_org_updates', where: 'id = ?', whereArgs: [id]);
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

    if (dailyStats != null) {
      await setCachedStat('daily_stats', dailyStats);
    }
  }

  // ── Planned Visits ────────────────────────────────────────────────────────

  Future<void> upsertPlannedVisits(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'planned_visits',
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getPlannedVisits({
    bool? completedOnly,
  }) async {
    if (completedOnly == true) {
      return db.query(
        'planned_visits',
        where: "status = 'completed'",
        orderBy: 'visit_date DESC',
      );
    }
    if (completedOnly == false) {
      return db.query(
        'planned_visits',
        where: "status != 'completed'",
        orderBy: 'visit_date DESC',
      );
    }
    return db.query('planned_visits', orderBy: 'visit_date DESC');
  }

  Future<void> clearPlannedVisits() async {
    await db.delete('planned_visits');
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
  }

  Future<List<Map<String, dynamic>>> getDayTypes() async {
    return db.query('day_types', orderBy: 'id');
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
  }

  Future<void> clearOrgFavorites() async {
    await db.update('organisations', {'is_favorite': 0});
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

    await db.transaction((txn) async {
      await txn.delete('organisations');
      await txn.delete('doctors');
      await txn.delete('doctor_organisations');
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
      for (final table in const [
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
      ]) {
        await txn.delete(table);
      }
      await txn.delete('sync_meta');
    });
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
    return db.insert(
      'doctors',
      doctor,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertDoctors(List<Map<String, dynamic>> doctors) async {
    if (doctors.isEmpty) return;
    final batch = db.batch();
    for (final row in doctors) {
      batch.insert(
        'doctors',
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
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
  }

  Future<int> updateDoctorFavorite(int doctorId, bool isFavorite) async {
    return db.update(
      'doctors',
      {
        'is_favorite': isFavorite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [doctorId],
    );
  }

  Future<void> clearDoctorFavorites() async {
    await db.update('doctors', {
      'is_favorite': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
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
  }

  Future<void> updateMaterialCachedPath(int id, String localPath) async {
    await db.update(
      'drug_materials',
      {'cached_path': localPath},
      where: 'id = ?',
      whereArgs: [id],
    );
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
  }

  Future<void> updateDrugName(int drugId, String name) async {
    await db.update(
      'drugs',
      {'name': name},
      where: 'id = ?',
      whereArgs: [drugId],
    );
  }

  Future<void> upsertOrganisations(List<Map<String, dynamic>> orgs) async {
    if (orgs.isEmpty) return;
    final batch = db.batch();
    for (final row in orgs) {
      batch.insert(
        'organisations',
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
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

  Future<List<Map<String, dynamic>>> getVisits({bool? unsyncedOnly}) async {
    if (unsyncedOnly == true) {
      return db.query(
        'visits',
        where: 'is_synced = ?',
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
    return db.insert('visits', v, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteLegacyTestVisits() async {
    return db.delete(
      'visits',
      where:
          "org_name = ? OR notes LIKE ? OR (visit_type = ? AND doctor_id IS NULL AND remote_id IS NULL)",
      whereArgs: ['Тестовая организация', 'Офлайн визит %', 'lpu'],
    );
  }

  Future<void> updateVisitStatus(int id, String status, {String? notes}) async {
    final values = <String, dynamic>{
      'status': status,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) values['notes'] = notes;

    await db.update('visits', values, where: 'id = ?', whereArgs: [id]);
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
  }

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = ids.map((_) => '?').join(', ');
    await db.rawUpdate(
      'UPDATE visits SET is_synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
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
  }

  Future<int> unsyncedCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM visits WHERE is_synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
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
}
