import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// ── File type helpers ──────────────────────────────────────────────────────

enum _MediaType { image, video, pdf, document }

_MediaType _mediaTypeOf(String url, String? fileType, String? fileName) {
  final ft = (fileType ?? '').toLowerCase();
  if ({'image', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ft)) {
    return _MediaType.image;
  }
  if ({'video', 'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'}.contains(ft)) {
    return _MediaType.video;
  }
  if (ft == 'pdf') return _MediaType.pdf;

  // Fall back to file_name extension
  final nameExt =
      (fileName ?? '').split('.').last.toLowerCase();
  if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(nameExt)) {
    return _MediaType.image;
  }
  if ({'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'}.contains(nameExt)) {
    return _MediaType.video;
  }
  if (nameExt == 'pdf') return _MediaType.pdf;

  // Fall back to URL extension (usually no extension for uid-based URLs)
  final ext = Uri.tryParse(url)?.path.split('.').last.toLowerCase() ?? '';
  if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext)) {
    return _MediaType.image;
  }
  if ({'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'}.contains(ext)) {
    return _MediaType.video;
  }
  if (ext == 'pdf') return _MediaType.pdf;
  return _MediaType.document;
}

String _fileExtOf(Map<String, dynamic> material) {
  // Prefer file_name from raw_json (has real extension like .mp4, .pdf)
  final raw = material['raw_json'];
  if (raw is String && raw.isNotEmpty) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final fn = (j['file_name'] as String? ?? '');
      final ext = fn.split('.').last.toLowerCase();
      if (ext.isNotEmpty && ext != fn) return ext;
    } catch (_) {}
  }
  // Fallback to URL extension
  final url = (material['local_path'] as String? ?? '');
  final ext = url.split('.').last.split('?').first.toLowerCase();
  if (ext.length <= 5 && ext.isNotEmpty) return ext;
  return 'bin';
}

IconData _iconOf(_MediaType t) {
  switch (t) {
    case _MediaType.image:
      return Icons.image_rounded;
    case _MediaType.video:
      return Icons.play_circle_rounded;
    case _MediaType.pdf:
      return Icons.picture_as_pdf_rounded;
    case _MediaType.document:
      return Icons.description_rounded;
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────

class MaterialViewerScreen extends ConsumerStatefulWidget {
  final int drugId;
  final int initialIndex;

  const MaterialViewerScreen({
    super.key,
    required this.drugId,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MaterialViewerScreen> createState() =>
      _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends ConsumerState<MaterialViewerScreen> {
  final _pageController = PageController();
  Map<String, dynamic>? _drug;
  List<Map<String, dynamic>> _materials = [];
  int _currentIndex = 0;
  bool _loading = true;

  // Per-index state
  final _localPaths = <int, String>{};
  final _isDownloading = <int, bool>{};
  final _hasError = <int, bool>{};
  final _videoControllers = <int, VideoPlayerController>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(localDatabaseProvider);
    final drugs = await db.getDrugs(onlyWithPositivePrice: false);
    final drug = drugs.where((d) => d['id'] == widget.drugId).firstOrNull;
    final materials = await db.getDrugMaterials(widget.drugId);
    final safeIndex = materials.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, materials.length - 1);

    setState(() {
      _drug = drug;
      _materials = materials;
      _currentIndex = safeIndex;
      _loading = false;
    });

    if (materials.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(safeIndex);
        _prepare(safeIndex);
      });
    }
  }

  String _resolveUrl(String rawPath) {
    if (rawPath.startsWith('http')) return rawPath;
    final baseUrl = ref.read(apiClientProvider).dio.options.baseUrl;
    final base = Uri.parse(baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (rawPath.startsWith('/api/')) return '$origin$rawPath';
    if (rawPath.startsWith('/')) return '$origin/api$rawPath';
    return '$origin/api/$rawPath';
  }

  String? get _token => ref.read(apiClientProvider).token;

  _MediaType _typeAt(int index) {
    final m = _materials[index];
    final url = (m['local_path'] as String?) ?? '';
    final ft = m['file_type'] as String?;
    final raw = m['raw_json'] as String?;
    String? fileName;
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        fileName = j['file_name'] as String?;
      } catch (_) {}
    }
    return _mediaTypeOf(url, ft, fileName);
  }

  Future<void> _prepare(int index) async {
    if (index >= _materials.length) return;
    final type = _typeAt(index);

    if (type == _MediaType.image) {
      await _downloadToLocal(index);
    } else if (type == _MediaType.video) {
      await _initVideo(index);
    }
  }

  Future<void> _downloadToLocal(int index) async {
    if (_localPaths.containsKey(index)) return;
    if (_isDownloading[index] == true) return;

    final material = _materials[index];
    final cached = (material['cached_path'] as String?) ?? '';
    if (cached.isNotEmpty && File(cached).existsSync()) {
      if (mounted) setState(() => _localPaths[index] = cached);
      return;
    }

    if (mounted) setState(() => _isDownloading[index] = true);
    try {
      final rawUrl = (material['local_path'] as String?) ?? '';
      final fullUrl = _resolveUrl(rawUrl);
      final dir = await getTemporaryDirectory();
      final ext = _fileExtOf(material);
      final savePath = '${dir.path}/lima_img_${widget.drugId}_$index.$ext';

      if (!File(savePath).existsSync()) {
        await Dio().download(
          fullUrl,
          savePath,
          options: Options(
            headers: _token != null
                ? {'Authorization': 'Bearer $_token'}
                : null,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _localPaths[index] = savePath;
          _isDownloading[index] = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading[index] = false;
          _hasError[index] = true;
        });
      }
    }
  }

  Future<void> _initVideo(int index) async {
    if (_videoControllers.containsKey(index)) return;
    if (_isDownloading[index] == true) return;

    final material = _materials[index];
    if (mounted) setState(() => _isDownloading[index] = true);

    try {
      // Use persistent cached file if available
      final cached = (material['cached_path'] as String?) ?? '';
      String savePath;
      if (cached.isNotEmpty && File(cached).existsSync()) {
        savePath = cached;
      } else {
        final rawUrl = (material['local_path'] as String?) ?? '';
        final fullUrl = _resolveUrl(rawUrl);
        final dir = await getTemporaryDirectory();
        final ext = _fileExtOf(material);
        savePath = '${dir.path}/lima_vid_${widget.drugId}_$index.$ext';
        if (!File(savePath).existsSync()) {
          await Dio().download(
            fullUrl,
            savePath,
            options: Options(
              headers: _token != null
                  ? {'Authorization': 'Bearer $_token'}
                  : null,
            ),
          );
        }
      }

      final controller = VideoPlayerController.file(File(savePath));
      await controller.initialize();

      if (mounted) {
        setState(() {
          _videoControllers[index] = controller;
          _localPaths[index] = savePath;
          _isDownloading[index] = false;
        });
      } else {
        controller.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading[index] = false;
          _hasError[index] = true;
        });
      }
    }
  }

  Future<void> _openExternal(int index) async {
    if (index >= _materials.length) return;
    final material = _materials[index];

    // Check in-memory path first
    final local = _localPaths[index];
    if (local != null && File(local).existsSync()) {
      await OpenFilex.open(local);
      return;
    }

    // Check persistent cached_path from DB
    final cached = (material['cached_path'] as String?) ?? '';
    if (cached.isNotEmpty && File(cached).existsSync()) {
      await OpenFilex.open(cached);
      return;
    }

    if (mounted) setState(() => _isDownloading[index] = true);
    try {
      final rawUrl = (material['local_path'] as String?) ?? '';
      final fullUrl = _resolveUrl(rawUrl);
      final dir = await getTemporaryDirectory();
      final ext = _fileExtOf(material);
      final title = (material['title'] as String? ?? 'file_$index')
          .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
      final savePath = '${dir.path}/lima_${widget.drugId}_$title.$ext';

      if (!File(savePath).existsSync()) {
        await Dio().download(
          fullUrl,
          savePath,
          options: Options(
            headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _localPaths[index] = savePath;
          _isDownloading[index] = false;
        });
        await OpenFilex.open(savePath);
      }
    } catch (_) {
      if (mounted) setState(() => _isDownloading[index] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0E17),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_drug == null || _materials.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E17),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(''),
              const Expanded(
                child: Center(
                  child: Text('Материалы не найдены',
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(_drug!['name'] as String? ?? ''),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _materials.length,
                onPageChanged: (i) {
                  // Pause previous video
                  _videoControllers[_currentIndex]?.pause();
                  setState(() => _currentIndex = i);
                  _prepare(i);
                },
                itemBuilder: (_, index) => _buildPreview(index),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String drugName) {
    return Container(
      color: const Color(0xFF111421),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _TopBtn(icon: Icons.close_rounded, onTap: () => context.pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Документы',
                    style: GoogleFonts.manrope(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                if (drugName.isNotEmpty)
                  Text(drugName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _TopBtn(
            icon: Icons.download_rounded,
            onTap: () => _openExternal(_currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(int index) {
    final type = _typeAt(index);
    final isLoading = _isDownloading[index] == true;
    final hasErr = _hasError[index] == true;

    switch (type) {
      case _MediaType.image:
        final localPath = _localPaths[index];
        if (isLoading) return _loadingPlaceholder('Загрузка изображения...');
        if (hasErr || localPath == null) return _errorPlaceholder(index);
        return Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.file(
                  File(localPath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, e, s) => _errorPlaceholder(index),
                ),
              ),
            ),
            _fullscreenBtn(index),
          ],
        );

      case _MediaType.video:
        final controller = _videoControllers[index];
        if (isLoading) return _loadingPlaceholder('Загрузка видео...');
        if (hasErr) return _errorPlaceholder(index);
        if (controller == null) return _loadingPlaceholder('Загрузка видео...');
        return Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            // Play/pause overlay
            GestureDetector(
              onTap: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
            ),
            // Progress bar at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
            _fullscreenBtn(index),
          ],
        );

      case _MediaType.pdf:
      case _MediaType.document:
        if (isLoading) return _loadingPlaceholder('Загрузка документа...');
        final mat = _materials[index];
        final cachedDoc = (mat['cached_path'] as String?) ?? '';
        final isDocCached = cachedDoc.isNotEmpty && File(cachedDoc).existsSync();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(_iconOf(type), color: Colors.white70, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                mat['title'] as String? ?? '',
                style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDocCached ? Icons.offline_pin_rounded : Icons.cloud_outlined,
                    color: isDocCached ? AppColors.success : Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDocCached ? 'Доступно офлайн' : 'Открывается во внешнем приложении',
                    style: GoogleFonts.manrope(
                        color: isDocCached ? AppColors.success : Colors.white54,
                        fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _openExternal(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Открыть',
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF111421),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _materials.length,
              separatorBuilder: (_, i) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final mat = _materials[index];
                final selected = index == _currentIndex;
                final type = _typeAt(index);
                return GestureDetector(
                  onTap: () {
                    _videoControllers[_currentIndex]?.pause();
                    _pageController.animateToPage(index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut);
                    _prepare(index);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF1E2235)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_iconOf(type),
                                color: selected
                                    ? AppColors.primary
                                    : Colors.white54,
                                size: 22),
                            const SizedBox(height: 6),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                mat['title'] as String? ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  color: selected
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Закрыть',
                  style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingPlaceholder(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(msg,
                style: GoogleFonts.manrope(
                    color: Colors.white54, fontSize: 13)),
          ],
        ),
      );

  Widget _errorPlaceholder(int index) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text('Не удалось загрузить',
                style: GoogleFonts.manrope(
                    color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _hasError[index] = false);
                _prepare(index);
              },
              child: Text('Повторить',
                  style: GoogleFonts.manrope(
                      color: AppColors.primary, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _fullscreenBtn(int index) => Positioned(
        right: 12,
        bottom: 12,
        child: GestureDetector(
          onTap: () => _openExternal(index),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.fullscreen_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      );
}

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
