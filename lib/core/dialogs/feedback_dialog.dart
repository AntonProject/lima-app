import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:path_provider/path_provider.dart';

void showFeedbackDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _FeedbackDialog(),
  );
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog();

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _enqueueOffline(String message, List<String> photoPaths) async {
    // Copy photos to persistent dir so they survive until upload
    final dir = await getApplicationSupportDirectory();
    final feedbackDir = Directory('${dir.path}/pending_feedback');
    if (!feedbackDir.existsSync()) feedbackDir.createSync(recursive: true);

    final persistedPaths = <String>[];
    for (final p in photoPaths) {
      try {
        final src = File(p);
        if (!src.existsSync()) continue;
        final ext = p.split('.').last;
        final dst = File('${feedbackDir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext');
        await src.copy(dst.path);
        persistedPaths.add(dst.path);
      } catch (_) {}
    }

    final db = ref.read(localDatabaseProvider);
    await db.enqueueFeedback(message, persistedPaths);
  }

  Future<void> _pickFromCamera() async {
    if (_images.length >= 5) return;
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;
    setState(() => _images.add(picked));
  }

  Future<void> _pickFromGallery() async {
    final remain = 5 - _images.length;
    if (remain <= 0) return;
    final picked = await _picker.pickMultiImage(limit: remain);
    if (picked.isEmpty || !mounted) return;
    setState(() => _images.addAll(picked.take(remain)));
  }

  Future<void> _showPhotoPicker() async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(context.l10n.t('takePhoto')),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(context.l10n.t('pickFromGallery')),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: shadowMd,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.t('feedback'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: AppColors.primaryText)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: context.l10n.t('feedbackHint'),
                hintStyle: GoogleFonts.manrope(color: AppColors.hintText),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: _images.length >= 5 ? null : _showPhotoPicker,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_a_photo_rounded,
                            color: AppColors.secondaryText, size: 16),
                        const SizedBox(width: 4),
                        Text(context.l10n.t('photos'),
                            style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: AppColors.secondaryText)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                    context.l10n.t(
                      'photosOptional',
                      args: {'count': '${_images.length}'},
                    ),
                    style: GoogleFonts.manrope(
                        fontSize: 11, color: AppColors.hintText)),
              ],
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final img = _images[i];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(img.path),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTapScale(
                    pressedScale: 0.97,
                    onTap: () => Navigator.pop(context),
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: const BorderSide(color: AppColors.border),
                        disabledForegroundColor: AppColors.secondaryText,
                      ),
                      child: Text(context.l10n.t('cancel'),
                          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTapScale(
                    pressedScale: 0.97,
                    onTap: _sending ? null : () async {
                      if (_ctrl.text.trim().isEmpty) return;
                      setState(() => _sending = true);
                      final message = _ctrl.text.trim();
                      final photoPaths = _images.map((e) => e.path).toList();
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final tSent = context.l10n.t('messageSent');
                      final tOffline = context.l10n.t('offlineWillSend');
                      final tFailed = context.l10n.t('sendFailed');
                      try {
                        final api = ref.read(remoteApiServiceProvider);
                        await api.sendFeedback(
                          message: message,
                          photoPaths: photoPaths,
                        );
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(content: Text(tSent)),
                        );
                      } on DioException catch (e) {
                        final isOffline = e.response == null ||
                            e.type == DioExceptionType.connectionError ||
                            e.type == DioExceptionType.connectionTimeout ||
                            e.type == DioExceptionType.receiveTimeout ||
                            e.type == DioExceptionType.sendTimeout;
                        if (isOffline) {
                          await _enqueueOffline(message, photoPaths);
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text(tOffline)),
                          );
                        } else {
                          if (!mounted) return;
                          setState(() => _sending = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text(tFailed)),
                          );
                        }
                      } catch (_) {
                        if (!mounted) return;
                        setState(() => _sending = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text(tFailed)),
                        );
                      }
                    },
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        disabledBackgroundColor: _sending ? AppColors.border : AppColors.primary,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: Text(context.l10n.t('send'),
                          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
