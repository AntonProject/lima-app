import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../domain/services/material_access_service.dart';

class MaterialAccessServiceImpl implements MaterialAccessService {
  final ApiClient _api;

  const MaterialAccessServiceImpl(this._api);

  @override
  Future<String> ensureLocal(
    DrugMaterial material, {
    required String cacheName,
  }) async {
    final cached = material.cachedPath ?? '';
    if (cached.isNotEmpty && File(cached).existsSync()) return cached;

    final rawPath = material.url;
    if (rawPath.isEmpty) throw StateError('Material URL is empty');
    final directory = await getTemporaryDirectory();
    final extension = _extension(material.fileName, rawPath);
    final savePath = '${directory.path}/$cacheName.$extension';
    if (!File(savePath).existsSync()) {
      await _api.dio.download(_resolveUrl(rawPath), savePath);
    }
    return savePath;
  }

  String _resolveUrl(String rawPath) {
    if (rawPath.startsWith('http')) return rawPath;
    final base = Uri.parse(_api.dio.options.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (rawPath.startsWith('/api/')) return '$origin$rawPath';
    if (rawPath.startsWith('/')) return '$origin/api$rawPath';
    return '$origin/api/$rawPath';
  }

  static String _extension(String? fileName, String url) {
    final named = (fileName ?? '').split('.').last.toLowerCase();
    if (named.isNotEmpty && named != fileName) return _safeExtension(named);
    final fromUrl = url.split('.').last.split('?').first.toLowerCase();
    if (fromUrl.isNotEmpty && fromUrl.length <= 5) {
      return _safeExtension(fromUrl);
    }
    return 'bin';
  }

  static String _safeExtension(String value) {
    final normalized = value.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.isEmpty ? 'bin' : normalized;
  }
}
