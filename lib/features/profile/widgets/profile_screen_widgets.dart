part of '../screens/profile_screen.dart';

const _divider = Divider(height: 1, thickness: 0.5, color: AppColors.divider);

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryText,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _HeaderStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _HeaderStatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppTapScale(
        pressedScale: 0.93,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // Fixed to the icon height so the value/label hug the icon's
                // top/bottom edges, with 2px insets to pull them slightly in.
                child: SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.iconBgBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isLink ? AppColors.primary : AppColors.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLink)
              const Icon(
                Icons.chevron_right,
                color: AppColors.hintText,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            )
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: AppColors.hintText, size: 20)
          : null,
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile();

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    final prefEnabled = prefs.getBool('notifications_enabled') ?? false;
    final status = await Permission.notification.status;
    final enabled = prefEnabled && status.isGranted;
    if (mounted) {
      setState(() => _enabled = enabled);
    }
    if (prefEnabled != enabled) {
      await prefs.setBool('notifications_enabled', enabled);
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // Request OS authorization via the local-notifications plugin: this fires
      // the iOS system prompt on first use and registers the app with
      // UNUserNotificationCenter, so a "Notifications" row appears in Settings.
      // (permission_handler alone failed to create that row when the app had no
      // notification plugin configured, leaving the toggle at a dead-end.)
      final granted = await LocalNotificationsService.instance
          .requestPermission();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', granted);
      if (mounted) setState(() => _enabled = granted);
      final status = await Permission.notification.status;
      if (!granted &&
          (status.isPermanentlyDenied || status.isRestricted) &&
          mounted) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.t('notifAccessTitle')),
            content: Text(ctx.l10n.t('notifPermDisabled')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.t('openSettings')),
              ),
            ],
          ),
        );
        if (openSettings == true) await openAppSettings();
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      setState(() => _enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.iconBgBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.notifications_rounded,
          color: AppColors.primary,
          size: 18,
        ),
      ),
      title: Text(
        AppI18n.of(context).t('notifications'),
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryText,
        ),
      ),
      trailing: Switch(
        value: _enabled,
        onChanged: _toggle,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
      ),
    );
  }
}

class _AppVersionLabel extends StatefulWidget {
  const _AppVersionLabel();

  @override
  State<_AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<_AppVersionLabel> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _version = '${info.version}+${info.buildNumber}');
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Text(
        'v$_version',
        style: GoogleFonts.manrope(fontSize: 12, color: AppColors.hintText),
      ),
    );
  }
}
