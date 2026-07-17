import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/material_viewer_provider.dart';
import '../presentation/view_models/material_viewer_view_model.dart';
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
  final nameExt = (fileName ?? '').split('.').last.toLowerCase();
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
  final _videoControllers = <int, VideoPlayerController>{};
  bool _initialPageApplied = false;

  MaterialViewerKey get _providerKey =>
      (drugId: widget.drugId, initialIndex: widget.initialIndex);

  MaterialViewerViewModel get _viewModel =>
      ref.read(materialViewerViewModelProvider(_providerKey).notifier);

  MaterialViewerViewState get _viewState =>
      ref.read(materialViewerViewModelProvider(_providerKey));

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  _MediaType _typeAt(int index) {
    final m = _viewState.materials[index];
    return _mediaTypeOf(m.url, m.fileType, m.fileName);
  }

  Future<void> _prepare(int index) async {
    if (index >= _viewState.materials.length) return;
    final type = _typeAt(index);

    if (type == _MediaType.image) {
      await _downloadToLocal(index);
    } else if (type == _MediaType.video) {
      await _initVideo(index);
    }
  }

  Future<void> _downloadToLocal(int index) async {
    await _viewModel.ensureLocal(
      index,
      cacheName: 'lima_img_${widget.drugId}_$index',
    );
  }

  Future<void> _initVideo(int index) async {
    if (_videoControllers.containsKey(index)) return;
    final savePath = await _viewModel.ensureLocal(
      index,
      cacheName: 'lima_vid_${widget.drugId}_$index',
    );
    if (savePath == null) return;

    try {
      final controller = VideoPlayerController.file(File(savePath));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _videoControllers[index] = controller);
    } catch (error) {
      logSwallowed(error, 'MaterialViewerScreen.initVideo');
      _viewModel.retry(index);
    }
  }

  Future<void> _openExternal(int index) async {
    if (index >= _viewState.materials.length) return;

    // Check in-memory path first
    final local = _viewState.localPaths[index];
    if (local != null && File(local).existsSync()) {
      await OpenFilex.open(local);
      return;
    }

    final material = _viewState.materials[index];
    final title = (material.title.isEmpty ? 'file_$index' : material.title)
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final savePath = await _viewModel.ensureLocal(
      index,
      cacheName: 'lima_${widget.drugId}_$title',
    );
    if (savePath != null) await OpenFilex.open(savePath);
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(materialViewerViewModelProvider(_providerKey));
    if (viewState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0E17),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewState.drug == null || viewState.materials.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E17),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(''),
              Expanded(
                child: Center(
                  child: Text(
                    context.l10n.t('materialsNotFound'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialPageApplied) {
      _initialPageApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(viewState.currentIndex);
        _prepare(viewState.currentIndex);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(viewState.drug!.name),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: viewState.materials.length,
                onPageChanged: (i) {
                  // Pause previous video
                  _videoControllers[viewState.currentIndex]?.pause();
                  _viewModel.setCurrentIndex(i);
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
                Text(
                  context.l10n.t('documents'),
                  style: GoogleFonts.manrope(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (drugName.isNotEmpty)
                  Text(
                    drugName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          _TopBtn(
            icon: Icons.download_rounded,
            onTap: () => _openExternal(_viewState.currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(int index) {
    final type = _typeAt(index);
    final state = _viewState;
    final isLoading = state.isDownloading(index);
    final hasErr = state.hasFailed(index);

    switch (type) {
      case _MediaType.image:
        final localPath = state.localPaths[index];
        if (isLoading) {
          return _loadingPlaceholder(context.l10n.t('loadingImage'));
        }
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
        if (isLoading) {
          return _loadingPlaceholder(context.l10n.t('loadingVideo'));
        }
        if (hasErr) return _errorPlaceholder(index);
        if (controller == null) {
          return _loadingPlaceholder(context.l10n.t('loadingVideo'));
        }
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
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
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
        if (isLoading) return _loadingPlaceholder(context.l10n.t('loadingDoc'));
        final mat = state.materials[index];
        final cachedDoc = mat.cachedPath ?? '';
        final isDocCached =
            cachedDoc.isNotEmpty && File(cachedDoc).existsSync();
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
                mat.title,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDocCached
                        ? Icons.offline_pin_rounded
                        : Icons.cloud_outlined,
                    color: isDocCached ? AppColors.success : Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDocCached
                        ? context.l10n.t('availableOffline')
                        : context.l10n.t('opensInExtApp'),
                    style: GoogleFonts.manrope(
                      color: isDocCached ? AppColors.success : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _openExternal(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.t('open'),
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _viewState.materials.length,
              separatorBuilder: (_, i) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final state = _viewState;
                final mat = state.materials[index];
                final selected = index == state.currentIndex;
                final type = _typeAt(index);
                return GestureDetector(
                  onTap: () {
                    _videoControllers[state.currentIndex]?.pause();
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
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
                            Icon(
                              _iconOf(type),
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white54,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                mat.title,
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
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.l10n.t('close'),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
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
          strokeWidth: 2,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          msg,
          style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _errorPlaceholder(int index) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Colors.white38,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.t('failedToLoad'),
          style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            _viewModel.retry(index);
            _prepare(index);
          },
          child: Text(
            context.l10n.t('retry'),
            style: GoogleFonts.manrope(color: AppColors.primary, fontSize: 13),
          ),
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
        child: const Icon(
          Icons.fullscreen_rounded,
          color: Colors.white,
          size: 22,
        ),
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
