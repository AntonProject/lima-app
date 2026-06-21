import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/dialogs/notification_detail_dialog.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/services/in_app_notifications_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final InAppNotificationsService _notificationsService =
      InAppNotificationsService();
  List<InAppNotificationItem> _notifications = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _notificationsService.getAll();
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _loading = false;
    });
  }

  String _formatTimeLabel(BuildContext context, DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    if (date == today) return context.l10n.t('todayAt', args: {'time': '$hh:$mm'});
    if (date == today.subtract(const Duration(days: 1))) {
      return context.l10n.t('yesterdayAt', args: {'time': '$hh:$mm'});
    }
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}, $hh:$mm';
  }

  Future<void> _openNotification(InAppNotificationItem item) async {
    if (!item.isRead) {
      await _notificationsService.markRead(item.id);
      await _load();
    }
    if (!mounted) return;
    await showNotificationDetailDialog(
      context,
      title: item.title,
      body: item.body,
    );
  }

  Future<void> _markAllRead() async {
    await _notificationsService.markAllRead();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              boxShadow: shadowSm,
            ),
            padding: EdgeInsets.fromLTRB(
              AppUi.screenHorizontal,
              MediaQuery.of(context).padding.top + 8,
              AppUi.screenHorizontal,
              12,
            ),
            child: Row(
              children: [
                AppTapScale(
                  onTap: () => context.pop(),
                  pressedScale: 0.93,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primaryText,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.t('notifications'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                if (_notifications.any((n) => !n.isRead))
                  AppTapScale(
                    onTap: _markAllRead,
                    pressedScale: 0.95,
                    child: Text(
                      context.l10n.t('readAll'),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _notifications.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.t('noNotifications'),
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppUi.screenHorizontal,
                      12,
                      AppUi.screenHorizontal,
                      24,
                    ),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final leftColor = n.isRead
                          ? AppColors.success.withValues(alpha: 0.6)
                          : AppColors.primary;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppTapScale(
                          onTap: () => _openNotification(n),
                          pressedScale: 0.95,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBg,
                              borderRadius: BorderRadius.circular(
                                AppUi.cardRadius,
                              ),
                              boxShadow: shadowSm,
                              border: Border(
                                left: BorderSide(color: leftColor, width: 3),
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatTimeLabel(context, n.createdAt),
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: AppColors.hintText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
