import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lima/core/db/local_database.dart';

/// Downloads drug material files to local storage so they are available offline.
/// Stores the local file path in `drug_materials.cached_path`.
class MaterialCacheService {
  final Dio _dio;
  final String? _authToken;

  MaterialCacheService({required Dio dio, String? authToken})
      : _dio = dio,
        _authToken = authToken;

  /// Downloads all materials that don't yet have a cached local file.
  /// Safe to call multiple times — skips already-cached files.
  Future<int> downloadPending(LocalDatabase db) async {
    final pending = await db.getMaterialsToCache();
    if (pending.isEmpty) return 0;

    final dir = await _cacheDir();
    var cachedCount = 0;

    for (final row in pending) {
      final id = row['id'] as int?;
      if (id == null) continue;
      final rawUrl = (row['local_path'] as String?) ?? '';
      if (rawUrl.isEmpty) continue;

      final fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : _resolveApiUrl(rawUrl);

      final fileName = _safeFileName(id, rawUrl);
      final file = File('${dir.path}/$fileName');

      // Skip if already downloaded (e.g. cached_path was cleared but file exists)
      if (await file.exists()) {
        await db.updateMaterialCachedPath(id, file.path);
        cachedCount++;
        continue;
      }

      try {
        await _dio.download(
          fullUrl,
          file.path,
          options: Options(
            headers: _authToken != null
                ? {'Authorization': 'Bearer $_authToken'}
                : {},
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        await db.updateMaterialCachedPath(id, file.path);
        cachedCount++;
      } catch (_) {
        // Non-fatal: file stays un-cached, will retry next sync
        if (await file.exists()) {
          try { await file.delete(); } catch (_) {}
        }
      }
    }
    return cachedCount;
  }

  /// Deletes all cached material files and clears cached_path in DB.
  Future<void> clearCache(LocalDatabase db) async {
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await db.db.execute("UPDATE drug_materials SET cached_path = NULL");
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/materials');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _safeFileName(int id, String url) {
    final ext = url.contains('.') ? '.${url.split('.').last.split('?').first}' : '.pdf';
    return 'material_$id$ext';
  }

  String _resolveApiUrl(String rawPath) {
    final base = Uri.parse(_dio.options.baseUrl);
    final origin = '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (rawPath.startsWith('/api/')) return '$origin$rawPath';
    if (rawPath.startsWith('/')) return '$origin/api$rawPath';
    return '$origin/api/$rawPath';
  }
}
