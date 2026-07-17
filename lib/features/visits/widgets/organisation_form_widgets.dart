import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../presentation/view_models/add_pharmacy_view_model.dart';

Future<Map<String, dynamic>?> showOrganisationPicker({
  required BuildContext context,
  required String title,
  required List<Map<String, dynamic>> options,
  required int? selectedId,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final bottomPad = MediaQuery.of(ctx).padding.bottom;
      final maxHeight = MediaQuery.of(ctx).size.height * 0.55 + bottomPad;
      return Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, index) {
                  final item = options[index];
                  final isSelected = item['id'] == selectedId;
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, item),
                    child: Container(
                      color: isSelected
                          ? const Color(0xFFF3F6FB)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['name']}',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primaryText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class OrganisationFormLabel extends StatelessWidget {
  final String text;

  const OrganisationFormLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
        ),
      ),
    );
  }
}

class OrganisationTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;

  const OrganisationTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.trailing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryText,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          fontSize: 13,
          color: AppColors.hintText,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: trailing,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
    );
  }
}

class OrganisationSelectField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback? onTap;

  const OrganisationSelectField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final selected = value != null && value!.isNotEmpty;
    return AppTapScale(
      pressedScale: 0.99,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6DEE8), width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected ? value! : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primaryText : AppColors.hintText,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: enabled
                  ? AppColors.hintText
                  : AppColors.hintText.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class OrganisationRevisionStatusSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const OrganisationRevisionStatusSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget radio(String option, String labelKey) {
      final selected = value == option;
      return InkWell(
        onTap: () => onChanged(option),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.primary : AppColors.hintText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.t(labelKey),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        radio('none', 'revisionNone'),
        radio('partial', 'revisionPartial'),
        radio('full', 'revisionFull'),
      ],
    );
  }
}

class OrganisationFormBody extends StatelessWidget {
  final bool isLpu;
  final AddPharmacyViewState form;
  final TextEditingController nameController;
  final TextEditingController innController;
  final TextEditingController addressController;
  final TextEditingController responsibleController;
  final List<TextEditingController> phoneControllers;
  final bool hasLocation;
  final bool canAddPhone;
  final VoidCallback onTextChanged;
  final VoidCallback onPickRegion;
  final VoidCallback onPickArea;
  final VoidCallback onPickFacilityType;
  final VoidCallback onPickCategory;
  final VoidCallback onPickMap;
  final VoidCallback onAddPhone;
  final ValueChanged<int> onRemovePhone;
  final ValueChanged<String> onRevisionStatusChanged;
  final ValueChanged<String> onPhoneChanged;

  const OrganisationFormBody({
    super.key,
    required this.isLpu,
    required this.form,
    required this.nameController,
    required this.innController,
    required this.addressController,
    required this.responsibleController,
    required this.phoneControllers,
    required this.hasLocation,
    required this.canAddPhone,
    required this.onTextChanged,
    required this.onPickRegion,
    required this.onPickArea,
    required this.onPickFacilityType,
    required this.onPickCategory,
    required this.onPickMap,
    required this.onAddPhone,
    required this.onRemovePhone,
    required this.onRevisionStatusChanged,
    required this.onPhoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        OrganisationFormLabel(
          text: isLpu
              ? context.l10n.t('lpuNameRequired')
              : context.l10n.t('orgNameRequired'),
        ),
        OrganisationTextField(
          controller: nameController,
          hint: isLpu
              ? context.l10n.t('lpuNamePlaceholder')
              : context.l10n.t('orgNamePlaceholder'),
          onChanged: (_) => onTextChanged(),
        ),
        const SizedBox(height: 14),
        OrganisationFormLabel(text: context.l10n.t('innRequired')),
        OrganisationTextField(
          controller: innController,
          hint: '123456789',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          onChanged: (_) => onTextChanged(),
        ),
        if (isLpu) ...[
          const SizedBox(height: 14),
          OrganisationFormLabel(text: context.l10n.t('revisionStatus')),
          OrganisationRevisionStatusSelector(
            value: form.revisionStatus,
            onChanged: onRevisionStatusChanged,
          ),
        ],
        const SizedBox(height: 14),
        OrganisationFormLabel(text: context.l10n.t('regionRequired')),
        OrganisationSelectField(
          value: form.regionName,
          hint: context.l10n.t('selectRegion'),
          onTap: onPickRegion,
        ),
        const SizedBox(height: 14),
        OrganisationFormLabel(
          text: isLpu ? context.l10n.t('areaRequired') : context.l10n.t('area'),
        ),
        OrganisationSelectField(
          value: form.areaName,
          hint: form.isLoadingAreas
              ? context.l10n.t('searching')
              : context.l10n.t('selectArea'),
          onTap: form.areas.isNotEmpty && !form.isLoadingAreas
              ? onPickArea
              : null,
        ),
        const SizedBox(height: 14),
        OrganisationFormLabel(text: context.l10n.t('addressRequired')),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: OrganisationTextField(
                controller: addressController,
                hint: context.l10n.t('enterAddress'),
                onChanged: (_) => onTextChanged(),
              ),
            ),
            const SizedBox(width: 8),
            _mapButton(onPickMap),
          ],
        ),
        if (isLpu) ...[
          const SizedBox(height: 14),
          OrganisationFormLabel(text: context.l10n.t('lpuType')),
          OrganisationSelectField(
            value: form.facilityTypeName,
            hint: context.l10n.t('selectLpuType'),
            onTap: form.facilityTypes.isNotEmpty ? onPickFacilityType : null,
          ),
        ],
        const SizedBox(height: 14),
        OrganisationPhonesSection(
          isLpu: isLpu,
          controllers: phoneControllers,
          canAddPhone: canAddPhone,
          onAddPhone: onAddPhone,
          onRemovePhone: onRemovePhone,
          onChanged: onPhoneChanged,
        ),
        const SizedBox(height: 14),
        OrganisationFormLabel(text: context.l10n.t('category')),
        OrganisationSelectField(
          value: form.categoryName,
          hint: context.l10n.t('selectCategory'),
          onTap: form.categories.isNotEmpty ? onPickCategory : null,
        ),
        const SizedBox(height: 14),
        OrganisationFormLabel(text: context.l10n.t('responsiblePerson')),
        OrganisationTextField(
          controller: responsibleController,
          hint: context.l10n.t('responsiblePlaceholder'),
          onChanged: (_) => onTextChanged(),
        ),
        const SizedBox(height: 14),
        AppTapScale(
          pressedScale: 0.98,
          onTap: onPickMap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasLocation
                      ? Icons.check_circle_outline_rounded
                      : Icons.location_on_outlined,
                  size: 18,
                  color: hasLocation
                      ? AppColors.success
                      : AppColors.secondaryText,
                ),
                const SizedBox(width: 8),
                Text(
                  hasLocation
                      ? context.l10n.t('locationSet')
                      : context.l10n.t('detectLocation'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasLocation
                        ? AppColors.success
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapButton(VoidCallback onTap) {
    return AppTapScale(
      pressedScale: 0.92,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6DEE8), width: 0.8),
        ),
        child: const Icon(
          Icons.map_outlined,
          color: AppColors.primary,
          size: 22,
        ),
      ),
    );
  }
}

class OrganisationPhonesSection extends StatelessWidget {
  final bool isLpu;
  final List<TextEditingController> controllers;
  final bool canAddPhone;
  final VoidCallback onAddPhone;
  final ValueChanged<int> onRemovePhone;
  final ValueChanged<String> onChanged;

  const OrganisationPhonesSection({
    super.key,
    required this.isLpu,
    required this.controllers,
    required this.canAddPhone,
    required this.onAddPhone,
    required this.onRemovePhone,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          context,
          isLpu ? context.l10n.t('phoneRequired') : context.l10n.t('phone'),
        ),
        for (var i = 0; i < controllers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _phoneField(
            controllers[i],
            onChanged,
            trailing: isLpu && i > 0
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.hintText,
                      size: 18,
                    ),
                    onPressed: () => onRemovePhone(i),
                  )
                : null,
          ),
        ],
        if (isLpu) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AppTapScale(
              pressedScale: 0.97,
              onTap: canAddPhone ? onAddPhone : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: canAddPhone
                        ? AppColors.primary
                        : const Color(0xFFD6DEE8),
                    width: canAddPhone ? 1 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: canAddPhone
                          ? AppColors.primary
                          : AppColors.hintText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.t('addPhone'),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: canAddPhone
                            ? AppColors.primary
                            : AppColors.hintText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _phoneField(
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    Widget? trailing,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [UzPhoneFormatter()],
      onChanged: onChanged,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryText,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintText: '+998901234567',
        hintStyle: GoogleFonts.manrope(
          fontSize: 13,
          color: AppColors.hintText,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: trailing,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6DEE8), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryText,
      ),
    ),
  );
}

class UzPhoneFormatter extends TextInputFormatter {
  static const _prefix = '+998';
  static const _maxDigitsAfterPrefix = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    var tail = digits.length > 3 ? digits.substring(3) : '';
    if (tail.length > _maxDigitsAfterPrefix) {
      tail = tail.substring(0, _maxDigitsAfterPrefix);
    }
    final text = '$_prefix$tail';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
