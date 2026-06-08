import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import '../theme/app_theme.dart';

class AppUi {
  static const double screenHorizontal = 12;
  static const double cardRadius = 16;
  static const double buttonRadius = 12;
  static const double buttonHeight = 44;
}

// ─── formatUzs ────────────────────────────────────────────────────────────────
String formatUzs(double amount, {bool short = false}) {
  if (short) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
  final formatted = amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );
  return '$formatted UZS';
}

// ─── LimaCard ────────────────────────────────────────────────────────────────
class LimaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;

  const LimaCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadowSm,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AppTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const AppTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.94,
  });

  @override
  State<AppTapScale> createState() => _AppTapScaleState();
}

class _AppTapScaleState extends State<AppTapScale> {
  double _scale = 1;
  bool _navigating = false;

  Future<void> _handleTap() async {
    if (_navigating) return;
    _navigating = true;
    HapticFeedback.lightImpact();
    // scale down
    setState(() => _scale = widget.pressedScale);
    await Future.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    // scale back up
    setState(() => _scale = 1);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _navigating = false;
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null ? null : _handleTap,
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() {
              _scale = 1;
              _navigating = false;
            }),
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class AppCenteredHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double horizontal;
  final double topExtra;
  final double bottom;
  final bool leftAlign;

  const AppCenteredHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.horizontal = 16,
    this.topExtra = 8,
    this.bottom = 12,
    this.leftAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = leftAlign ? TextAlign.left : TextAlign.center;
    final crossAxis = leftAlign
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        boxShadow: shadowSm,
      ),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        MediaQuery.of(context).padding.top + topExtra,
        horizontal,
        bottom,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.primaryText,
                  size: 24,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: crossAxis,
              children: [
                Text(
                  title,
                  textAlign: align,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    textAlign: align,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OrgCard ─────────────────────────────────────────────────────────────────
class OrgCard extends StatelessWidget {
  final String name;
  final String address;
  final bool isPharmacy;
  final double? distanceMeters;
  final VoidCallback onTap;

  const OrgCard({
    super.key,
    required this.name,
    required this.address,
    this.isPharmacy = false,
    this.distanceMeters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppTapScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: shadowSm,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPharmacy
                      ? AppColors.iconBgGreen
                      : AppColors.iconBgGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPharmacy
                      ? Icons.local_pharmacy_outlined
                      : Icons.home_work_rounded,
                  color: isPharmacy ? AppColors.success : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (distanceMeters != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_rounded,
                            size: 11,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            distanceMeters! < 1000
                                ? '${distanceMeters!.round()} м'
                                : '${(distanceMeters! / 1000).toStringAsFixed(1)} км',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.primary.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.hintText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DrugCard (детейлинг / база знаний) ──────────────────────────────────────
class DrugCard extends StatelessWidget {
  final String name;
  final String manufacturer;
  final VoidCallback? onDocument;
  final VoidCallback? onAssign;
  final bool isMandatory;

  const DrugCard({
    super.key,
    required this.name,
    required this.manufacturer,
    this.onDocument,
    this.onAssign,
    this.isMandatory = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: shadowSm,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isMandatory) ...[
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        manufacturer,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                _IconBtn(
                  icon: Icons.description_outlined,
                  onTap: onDocument ?? () {},
                ),
                const SizedBox(width: 8),
                _IconBtn(
                  icon: Icons.assignment_outlined,
                  onTap: onAssign ?? () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.secondaryText, size: 18),
      ),
    );
  }
}

// ─── DoctorCard (list item with checkbox) ─────────────────────────────────────
class DoctorCardCheckbox extends StatelessWidget {
  final String name;
  final String? category;
  final String? specialty;
  final String? lastVisit;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onInfo;

  const DoctorCardCheckbox({
    super.key,
    required this.name,
    this.category,
    this.specialty,
    this.lastVisit,
    required this.isSelected,
    this.isFavorite = false,
    required this.onTap,
    this.onFavorite,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppTapScale(
        onTap: onTap,
        pressedScale: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFDDE3EB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: shadowSm,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.iconBgLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category!,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (specialty != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.business_center_rounded,
                              size: 13,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                specialty!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (lastVisit != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          lastVisit!,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onFavorite != null || onInfo != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      if (onInfo != null)
                        GestureDetector(
                          onTap: onInfo,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.iconBgBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                        ),
                      if (onInfo != null && onFavorite != null)
                        const SizedBox(width: 6),
                      if (onFavorite != null)
                        GestureDetector(
                          onTap: onFavorite,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isFavorite
                                  ? const Color(0xFFFFE4F0)
                                  : AppColors.iconBgLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite
                                  ? const Color(0xFFE91E8C)
                                  : AppColors.hintText,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── InfoRow ──────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueTextStyle = GoogleFonts.manrope(
      fontSize: 14,
      color: isLink ? AppColors.primary : AppColors.primaryText,
      fontWeight: FontWeight.w500,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: isLink
                    ? GestureDetector(
                        onTap: onTap,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: valueTextStyle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      )
                    : Text(
                        value,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: valueTextStyle,
                      ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
      ],
    );
  }
}

// ─── HintBox ──────────────────────────────────────────────────────────────────
class HintBox extends StatelessWidget {
  final String text;

  const HintBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1E3FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('hint'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SectionLabel ─────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.hintText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── LimaSearchField ─────────────────────────────────────────────────────────
class LimaSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String value;

  const LimaSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    required this.value,
    this.onClear,
  });

  @override
  State<LimaSearchField> createState() => _LimaSearchFieldState();
}

class _LimaSearchFieldState extends State<LimaSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant LimaSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.hintText),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.hintText,
                  size: 18,
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  widget.onClear?.call();
                  if (mounted) setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.secondaryBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

// ─── EmptyState ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.hintText),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── PrimaryBlueHeader ────────────────────────────────────────────────────────
class PrimaryBlueHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  const PrimaryBlueHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        16,
      ),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ─── VisitStatusChip ──────────────────────────────────────────────────────────
class VisitStatusChip extends StatelessWidget {
  final bool isCompleted;

  const VisitStatusChip({super.key, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? context.l10n.t('completed') : context.l10n.t('planned'),
        style: GoogleFonts.manrope(
          fontSize: 10,
          color: isCompleted ? AppColors.success : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
