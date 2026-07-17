part of '../screens/lpu/lpu_detail_screen.dart';

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadowSm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: onTap == null ? AppColors.hintText : AppColors.primary,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: onTap == null
                    ? AppColors.hintText
                    : AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _LpuDetailScreenUi on _LpuDetailScreenState {
  Widget _buildDetailScaffold(BuildContext context) {
    ref.watch(organisationDetailsViewModelProvider(widget.orgId));
    ref.watch(lpuDetailsViewModelProvider(widget.orgId));
    final hasPhone = (_orgPhone() ?? '').trim().isNotEmpty;
    final phone = _orgPhone();
    final inn = _orgInn();
    final responsible = _orgResponsible();
    final category = _orgCategory();
    final worksWithUs = _worksWithUs();
    final displayAddress = (_org?.address ?? widget.orgAddress).trim();
    final ctaBottom = LimaNavBarLayout.ctaBottomOffset(context);

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          Column(
            children: [
              // ── AppBar ────────────────────────────────────────────────────
              AppCenteredHeader(
                title: context.l10n.t('lpu'),
                onBack: () => context.pop(),
              ),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, ctaBottom + 56),
                  children: [
                    // ── Org header card ────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.iconBgBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.home_work_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.orgName,
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                if ((category != null && category.isNotEmpty) ||
                                    worksWithUs != null) ...[
                                  const SizedBox(height: 8),
                                  // Category + status sit below the name and wrap
                                  // so a long org name never pushes the status
                                  // badge to float beside the middle of the text.
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (category != null &&
                                          category.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.iconBgLight,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            category,
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              color: AppColors.secondaryText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (worksWithUs != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: worksWithUs == true
                                                ? const Color(0xFFDDF5E6)
                                                : const Color(0xFFFFEEF0),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            worksWithUs == true
                                                ? context.l10n.t('worksWithUs')
                                                : context.l10n.t(
                                                    'notWorksWithUs',
                                                  ),
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: worksWithUs == true
                                                  ? const Color(0xFF2AA65A)
                                                  : AppColors.error,
                                              fontWeight: FontWeight.w600,
                                            ),
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
                    ),
                    const SizedBox(height: 10),

                    // ── Info ───────────────────────────────────────────────────
                    SectionLabel(text: context.l10n.t('informationCaps')),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if ((_org?.city ?? '').isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('region'),
                              value: _org!.city!,
                            ),
                          if (displayAddress.isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('address'),
                              value: displayAddress,
                            ),
                          if (phone != null && phone.isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('phone'),
                              value: phone,
                              isLink: true,
                              onTap: () => launchPhone(phone),
                            ),
                          if (inn != null && inn.isNotEmpty)
                            InfoRow(label: context.l10n.t('inn'), value: inn),
                          if (responsible != null && responsible.isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('responsible'),
                              value: responsible,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Call / Route / Edit ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.call_rounded,
                            label: context.l10n.t('call'),
                            onTap: hasPhone
                                ? () async {
                                    if (phone == null || phone.isEmpty) return;
                                    await launchPhone(phone);
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.near_me_rounded,
                            label: context.l10n.t('route'),
                            onTap: _buildYandexRoute,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.edit_rounded,
                            label: context.l10n.t('edit'),
                            onTap: _openEditOrganizationSheet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── History ────────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(
                          Uri(
                            path: '/visits/history',
                            queryParameters: {
                              'type': 'lpu',
                              'orgId': '${widget.orgId}',
                              'openFirst': '1',
                            },
                          ).toString(),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.iconBgBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.access_time_filled_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  context.l10n.t('visitHistory'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.hintText,
                                size: 21,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Doctors ────────────────────────────────────────────────
                    Row(
                      children: [
                        SectionLabel(text: context.l10n.t('doctorsCaps')),
                        const Spacer(),
                        Text(
                          '${_doctors.length}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    if (_doctors.isEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: shadowSm,
                        ),
                        child: ListTile(
                          title: Text(
                            context.l10n.t('doctorsNotFound'),
                            style: GoogleFonts.manrope(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _doctors.map((d) {
                          final isFavorite = d.isFavorite;
                          final name = d.fullName;
                          final specialty = d.specialty ?? '';
                          final doctorId = d.id;
                          final hadVisit = _visitedDoctorIds.contains(doctorId);
                          final expanded = _expandedDoctorIds.contains(
                            doctorId,
                          );
                          final category =
                              '${context.l10n.t('category')} ${d.category ?? 'C'}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDE3EB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.divider,
                                  width: 1,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryBg,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: shadowSm,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _toggleDoctorExpanded(doctorId),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          14,
                                          12,
                                          14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _toggleFavorite(d),
                                              child: Icon(
                                                isFavorite
                                                    ? Icons.bookmark_rounded
                                                    : Icons
                                                          .bookmark_border_rounded,
                                                color: AppColors.primary,
                                                size: 21,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              expanded
                                                  ? Icons
                                                        .keyboard_arrow_down_rounded
                                                  : Icons.chevron_right_rounded,
                                              color: AppColors.hintText,
                                              size: 21,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (expanded) ...[
                                        const Divider(
                                          height: 1,
                                          color: AppColors.divider,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            12,
                                            12,
                                            14,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.iconBgBlue,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  category,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.secondaryText,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.work_outline_rounded,
                                                    color: AppColors.hintText,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      specialty.isEmpty
                                                          ? '—'
                                                          : specialty,
                                                      style:
                                                          GoogleFonts.manrope(
                                                            fontSize: 14,
                                                            color: AppColors
                                                                .secondaryText,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (hadVisit) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: AppColors.success,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      context.l10n.t(
                                                        'hadVisit',
                                                      ),
                                                      style:
                                                          GoogleFonts.manrope(
                                                            fontSize: 13,
                                                            color: AppColors
                                                                .success,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: ctaBottom,
            child: ElevatedButton(
              onPressed: () => context.push(
                Uri(
                  path: '/visits/lpu/detail/${widget.orgId}/doctors',
                  queryParameters: {'name': widget.orgName},
                ).toString(),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.l10n.t('startVisit')),
            ),
          ),
        ],
      ),
    );
  }
}
