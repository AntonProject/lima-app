import 'dart:io';

import 'package:dio/dio.dart';
// iOS 26 simulators can fail while path_provider loads its Objective-C native
// asset. Material downloads only need a sandboxed temporary directory, which
// dart:io provides without a platform channel.

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
    if (cached.isNotEmpty && await _hasContent(File(cached))) return cached;

    final rawPath = material.url;
    if (rawPath.isEmpty) throw StateError('Material URL is empty');
    final directory = Directory.systemTemp;
    if (!await directory.exists()) await directory.create(recursive: true);
    final extension = _extension(material.fileName, rawPath, material.fileType);
    final savePath = '${directory.path}/$cacheName.$extension';
    final target = File(savePath);
    if (await _hasContent(target)) return savePath;

    final partialPath = '$savePath.part';
    final partial = File(partialPath);
    if (await partial.exists()) await partial.delete();
    try {
      // Video files can take considerably longer than the 15-second timeout
      // used for ordinary API JSON requests.
      await _api.dio.download(
        _resolveUrl(rawPath),
        partialPath,
        options: Options(receiveTimeout: const Duration(minutes: 3)),
      );
      if (!await _hasContent(partial)) {
        throw StateError('Downloaded material is empty');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(savePath);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      if (await target.exists() && !await _hasContent(target)) {
        await target.delete();
      }
      rethrow;
    }
    return savePath;
  }

  static Future<bool> _hasContent(File file) async {
    if (!await file.exists()) return false;
    return (await file.length()) > 0;
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

  static String _extension(String? fileName, String url, String fileType) {
    final named = (fileName ?? '').split('.').last.toLowerCase();
    if (named.isNotEmpty && named != fileName) return _safeExtension(named);
    final normalizedType = fileType.trim().toLowerCase();
    if (normalizedType.contains('mp4') ||
        normalizedType == 'video' ||
        normalizedType.contains('video') ||
        normalizedType.contains('видео')) {
      return 'mp4';
    }
    if (normalizedType.contains('pdf')) return 'pdf';
    final fromUrl = url.split('?').first.split('.').last.toLowerCase();
    if ({
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      'm4v',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'pdf',
    }.contains(fromUrl)) {
      return fromUrl;
    }
    return 'bin';
  }

  static String _safeExtension(String value) {
    final normalized = value.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.isEmpty ? 'bin' : normalized;
  }
}
