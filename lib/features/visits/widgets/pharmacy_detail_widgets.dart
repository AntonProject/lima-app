part of '../screens/pharmacy/pharmacy_detail_screen.dart';

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

extension _PharmacyDetailScreenUi on _PharmacyDetailScreenState {
  Widget _buildDetailScaffold(BuildContext context) {
    ref.watch(organisationDetailsViewModelProvider(widget.pharmacyId));
    final collections = ref.watch(appCollectionsProvider);
    final isFavorite = collections.favoritePharmacyIds.contains(
      widget.pharmacyId,
    );
    final address = _org?.address ?? '';
    final city = _org?.city ?? '';
    final phone = _orgPhone();
    final inn = _orgInn();
    final category = _orgCategory();
    final worksWithUs = _worksWithUs();
    final ctaBottom = LimaNavBarLayout.ctaBottomOffset(context);

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          Column(
            children: [
              AppCenteredHeader(
                title: context.l10n.t('pharmacyOne'),
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, ctaBottom + 56),
                  children: [
                    // Org header card
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
                              color: AppColors.iconBgGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.medication_rounded,
                              color: AppColors.success,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.pharmacyName,
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
                                  // so a long name never floats the status badge
                                  // beside the middle of the text.
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
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final added = await ref
                                  .read(appCollectionsProvider.notifier)
                                  .toggleFavoritePharmacy(widget.pharmacyId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added
                                        ? context.l10n.t('addedToFav')
                                        : context.l10n.t('removedFromFav'),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 10),
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
                          if (city.isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('region'),
                              value: city,
                            ),
                          if (address.isNotEmpty)
                            InfoRow(
                              label: context.l10n.t('address'),
                              value: address,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.call_rounded,
                            label: context.l10n.t('call'),
                            onTap: (phone == null || phone.isEmpty)
                                ? null
                                : () => launchPhone(phone),
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
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: shadowSm,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.iconBgBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          context.l10n.t('orderHistory'),
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.hintText,
                        ),
                        onTap: () => context.push(
                          Uri(
                            path: '/visits/history',
                            queryParameters: {
                              'type': 'pharmacy',
                              'orgId': '${widget.pharmacyId}',
                              'openFirst': '1',
                            },
                          ).toString(),
                        ),
                      ),
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
                  path: '/visits/pharmacy/detail/${widget.pharmacyId}/type',
                  queryParameters: {'name': widget.pharmacyName},
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
