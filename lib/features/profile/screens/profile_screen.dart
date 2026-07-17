import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/theme/app_icons.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/core/services/app_actions.dart';
import 'package:lima/core/dialogs/feedback_dialog.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/core/services/local_notifications_service.dart';
import 'package:lima/features/collections/providers/collections_repository_providers.dart';
import 'package:lima/features/knowledge/providers/knowledge_repository_provider.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';

part '../widgets/profile_screen_widgets.dart';

/// Role label for the profile — the server's exact role name, with a single
/// localized fallback when the server sent nothing.
String _roleDisplay(BuildContext context, UserModel? user) {
  final name = user?.roleName?.trim() ?? '';
  return name.isNotEmpty ? name : context.l10n.t('roleMp');
}

String _formatUzPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String local = digits;
  if (digits.startsWith('998')) {
    local = digits.substring(3);
  } else if (digits.startsWith('8') && digits.length == 12) {
    local = digits.substring(1);
  }
  if (local.length < 9) return raw;
  final d = local.substring(0, 9);
  return '+998 ${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 7)} ${d.substring(7, 9)}';
}

String _visitsLabel(BuildContext context, int count) =>
    context.l10n.pluralWord(count, 'visits');

String _doctorsLabel(BuildContext context, int count) =>
    context.l10n.pluralWord(count, 'doctors');

final favoriteDoctorsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  return ref.watch(favoritesRepositoryProvider).getFavoriteDoctorsCount();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final collections = ref.watch(appCollectionsProvider);
    final counts = ref.watch(dashboardCountsProvider).valueOrNull;
    final favoriteDoctorsCount = ref
        .watch(favoriteDoctorsCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);
    final visitsCount = counts?.visitsTotalCount ?? user?.visitsCount ?? 0;
    final doctorsCount = favoriteDoctorsCount;
    ref.listen<SyncState>(syncProvider, (prev, next) {
      final prevAt = prev?.lastSyncAt;
      final nextAt = next.lastSyncAt;
      if (nextAt == null) return;
      if (prevAt == null ||
          nextAt.millisecondsSinceEpoch != prevAt.millisecondsSinceEpoch) {
        ref.invalidate(favoriteDoctorsCountProvider);
        ref.invalidate(dashboardCountsProvider);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: ListView(
        padding: EdgeInsets.only(
          bottom: LimaNavBarLayout.scrollBottomPadding(context),
        ),
        children: [
          // ── Blue header ─────────────────────────────────────────────────
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 12,
              12,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Name + Role + City in a row (left-aligned)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user?.initials ?? '?',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _roleDisplay(context, user),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          if (user?.city != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  AppIcons.location,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  user!.city!,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats inside blue header
                Row(
                  children: [
                    _HeaderStatCard(
                      icon: AppIcons.location,
                      value: '$visitsCount',
                      label: _visitsLabel(context, visitsCount),
                      onTap: () => context.push('/visits/history'),
                    ),
                    const SizedBox(width: 8),
                    _HeaderStatCard(
                      icon: AppIcons.sales,
                      value: formatUzs(user?.salesAmount ?? 0, short: true),
                      label: context.l10n.t('sales'),
                    ),
                    const SizedBox(width: 8),
                    _HeaderStatCard(
                      icon: AppIcons.profile,
                      value: '$doctorsCount',
                      label: _doctorsLabel(context, doctorsCount),
                      onTap: () => context.push('/profile/fav-doctors'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Contact info ─────────────────────────────────────────────────
          if (user?.phone != null || user?.company != null) ...[
            _SectionHeader(context.l10n.t('contactInfo')),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: shadowSm,
                ),
                child: Column(
                  children: [
                    if (user?.phone != null)
                      _ContactRow(
                        icon: AppIcons.phone,
                        label: context.l10n.t('phone'),
                        value: _formatUzPhone(user!.phone!),
                        isLink: true,
                        onTap: () => launchPhone(user.phone!),
                      ),
                    if (user?.phone != null && user?.company != null)
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppColors.divider,
                      ),
                    if (user?.company != null)
                      _ContactRow(
                        icon: AppIcons.company,
                        label: context.l10n.t('company'),
                        value: user!.company!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Quick actions ────────────────────────────────────────────────
          _SectionHeader(context.l10n.t('quickActions')),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadowSm,
              ),
              child: Column(
                children: [
                  _ActionTile(
                    icon: AppIcons.history,
                    label: context.l10n.t('visitHistory'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/visits/history'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.calendar,
                    label: context.l10n.t('visitPlan'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.go('/plan'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.profile,
                    label: context.l10n.t('favDoctors'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/profile/fav-doctors'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.pharmacy,
                    label: context.l10n.t('favPharmacies'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/profile/fav-pharmacies'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.knowledge,
                    label: context.l10n.t('knowledge'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.go('/knowledge'),
                  ),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.cart,
                    label: context.l10n.t('cart'),
                    subtitle: collections.cartCount > 0
                        ? '${collections.cartCount} ${context.l10n.t('orders')}'
                        : null,
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/basket'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Settings ─────────────────────────────────────────────────────
          _SectionHeader(context.l10n.t('settings')),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadowSm,
              ),
              child: Column(
                children: [
                  const _NotificationTile(),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.trash,
                    label: context.l10n.t('clearCache'),
                    iconBg: AppColors.iconBgOrange,
                    iconColor: AppColors.accent,
                    onTap: () async {
                      await ref
                          .read(appCollectionsProvider.notifier)
                          .clearCart();
                      await ref
                          .read(knowledgeRepositoryProvider)
                          .clearMaterialsCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.t('cacheCleared')),
                          ),
                        );
                      }
                    },
                  ),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.userMinus,
                    label: context.l10n.t('deleteAccount'),
                    iconBg: const Color(0xFFFFEEEE),
                    iconColor: AppColors.error,
                    onTap: () => _confirmDeleteAccount(context, ref, user),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Support ─────────────────────────────────────────────────────
          _SectionHeader(context.l10n.t('support')),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadowSm,
              ),
              child: Column(
                children: [
                  _ActionTile(
                    icon: AppIcons.feedback,
                    label: context.l10n.t('feedback'),
                    iconBg: AppColors.iconBgBlue,
                    iconColor: AppColors.primary,
                    onTap: () => showFeedbackDialog(context),
                  ),
                  _divider,
                  _ActionTile(
                    icon: AppIcons.support,
                    label: context.l10n.t('techSupport'),
                    iconBg: AppColors.iconBgGreen,
                    iconColor: AppColors.success,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Logout ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: AppTapScale(
              pressedScale: 0.97,
              onTap: () => ref.read(authProvider.notifier).logout(),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.logout, color: AppColors.error, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.t('logout'),
                      style: GoogleFonts.manrope(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const _AppVersionLabel(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Account deletion for org-provisioned (B2B) accounts: the user cannot
/// self-delete, so we send a deletion request to LIMA support and sign out
/// locally. Satisfies App Store Guideline 5.1.1(v) for managed accounts.
Future<void> _confirmDeleteAccount(
  BuildContext context,
  WidgetRef ref,
  UserModel? user,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.t('deleteAccountTitle')),
      content: Text(l10n.t('deleteAccountInfo')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l10n.t('deleteAccountSend')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final body = StringBuffer()
    ..writeln('Account deletion request / Запрос на удаление аккаунта')
    ..writeln('---')
    ..writeln('User ID: ${user?.id ?? '-'}')
    ..writeln('Name: ${user?.fullName ?? '-'}')
    ..writeln('Phone: ${user?.phone ?? '-'}')
    ..writeln('Company: ${user?.company ?? '-'}');
  await launchEmailRequest(
    'info@lima.uz',
    subject: 'LIMA — account deletion request (ID ${user?.id ?? '-'})',
    body: body.toString(),
  );

  await ref.read(authProvider.notifier).logout();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('deleteAccountRequested'))),
    );
  }
}
