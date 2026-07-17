import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/visits/domain/entities/visit_interaction.dart';

class LpuDetailingContent extends StatelessWidget {
  final String organizationName;
  final String doctorCountLabel;
  final List<Drug> filteredDrugs;
  final Map<String, DrugStatus> statuses;
  final Map<String, Drug> drugByName;
  final VoidCallback onBack;
  final VoidCallback onDoctorsTap;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function(String drugName) onStatusTap;
  final ValueChanged<int> onMaterialsTap;

  const LpuDetailingContent({
    super.key,
    required this.organizationName,
    required this.doctorCountLabel,
    required this.filteredDrugs,
    required this.statuses,
    required this.drugByName,
    required this.onBack,
    required this.onDoctorsTap,
    required this.onQueryChanged,
    required this.onStatusTap,
    required this.onMaterialsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(context),
        Expanded(
          child: filteredDrugs.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: context.l10n.t('nothingFound'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
                  itemCount: filteredDrugs.length,
                  itemBuilder: (_, index) =>
                      _drugCard(context, filteredDrugs[index]),
                ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organizationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          doctorCountLabel,
                          style: GoogleFonts.manrope(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onDoctorsTap,
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: context.l10n.t('searchDrug'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drugCard(BuildContext context, Drug drug) {
    final name = drug.name;
    final selected = statuses.containsKey(name);
    final dbRow = drugByName[name.toLowerCase()];
    final drugId = dbRow?.id;
    final hasDocuments = (dbRow?.documentsCount ?? 0) > 0 && drugId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF0FF) : AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    drug.manufacturer,
                    style: GoogleFonts.manrope(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LpuDetailingActionIconBox(
              icon: Icons.description_outlined,
              active: false,
              disabled: !hasDocuments,
              onTap: hasDocuments ? () => onMaterialsTap(drugId) : null,
            ),
            const SizedBox(width: 8),
            LpuDetailingActionIconBox(
              icon: Icons.assignment_outlined,
              active: selected,
              onTap: () => onStatusTap(name),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable detailing action control. Keeping this out of the screen makes
/// the stateful screen responsible only for orchestration and navigation.
class LpuDetailingActionIconBox extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool disabled;
  final VoidCallback? onTap;

  const LpuDetailingActionIconBox({
    super.key,
    required this.icon,
    required this.active,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.primaryBg
              : active
              ? AppColors.iconBgBlue
              : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 23,
          color: disabled
              ? AppColors.hintText.withValues(alpha: 0.35)
              : active
              ? AppColors.primary
              : AppColors.secondaryText,
        ),
      ),
    );
  }
}

class LpuDetailingDoctorsInfoSheet extends StatefulWidget {
  final List<Doctor> doctors;

  const LpuDetailingDoctorsInfoSheet({super.key, required this.doctors});

  @override
  State<LpuDetailingDoctorsInfoSheet> createState() =>
      _LpuDetailingDoctorsInfoSheetState();
}

class _LpuDetailingDoctorsInfoSheetState
    extends State<LpuDetailingDoctorsInfoSheet> {
  Doctor? _detail;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: screenHeight * 0.6,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                context.l10n.t('doctorInfo'),
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            Divider(height: 16, thickness: 0.7, color: AppColors.divider),
            if (_detail != null)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _detail = null),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.t('backToList'),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.7,
                    color: AppColors.divider,
                  ),
                ],
              ),
            Expanded(
              child: SingleChildScrollView(
                child: _detail == null
                    ? _LpuDetailingDoctorList(
                        doctors: widget.doctors,
                        onSelect: (doctor) => setState(() => _detail = doctor),
                      )
                    : _LpuDetailingDoctorDetail(doctor: _detail!),
              ),
            ),
            const Divider(height: 1, thickness: 0.7, color: AppColors.divider),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(context.l10n.t('close')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LpuDetailingDoctorList extends StatelessWidget {
  final List<Doctor> doctors;
  final ValueChanged<Doctor> onSelect;

  const _LpuDetailingDoctorList({
    required this.doctors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(
          context.l10n.t('noDoctorsData'),
          style: GoogleFonts.manrope(color: AppColors.hintText),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: doctors.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 0.5, color: AppColors.divider),
      itemBuilder: (_, i) {
        final doctor = doctors[i];
        final specialty = doctor.specialty ?? '';
        return GestureDetector(
          onTap: () => onSelect(doctor),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.fullName,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (specialty.isNotEmpty)
                        Text(
                          specialty,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  lpuDetailingDoctorCategoryLabel(context, doctor),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.hintText,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LpuDetailingDoctorDetail extends StatelessWidget {
  final Doctor doctor;

  const _LpuDetailingDoctorDetail({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LpuDetailingDetailRow(
            label: context.l10n.t('fullName'),
            value: doctor.fullName,
          ),
          _LpuDetailingDetailRow(
            label: context.l10n.t('specialization'),
            value: doctor.specialty ?? '',
          ),
          _LpuDetailingDetailRow(
            label: context.l10n.t('category'),
            value: lpuDetailingDoctorCategoryLabel(context, doctor),
            isLast: true,
            asChip: true,
          ),
        ],
      ),
    );
  }
}

class _LpuDetailingDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final bool asChip;

  const _LpuDetailingDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.asChip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: asChip
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.iconBgLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        value,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String lpuDetailingDoctorCategoryLabel(BuildContext context, Doctor doctor) {
  var category = doctor.category?.trim();
  if (category == null || category.isEmpty) {
    final raw = doctor.rawJsonMap;
    category = (raw['category'] ?? raw['category_name'] ?? raw['class'])
        ?.toString()
        .trim();
  }
  final normalized = (category == null || category.isEmpty)
      ? 'C'
      : category.toUpperCase();
  return '${context.l10n.t('category')} $normalized';
}
