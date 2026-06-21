import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/theme/app_theme.dart';

Future<String?> showManagerSelectDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ManagerSelectSheet(),
  );
}

class _ManagerSelectSheet extends ConsumerStatefulWidget {
  const _ManagerSelectSheet();

  @override
  ConsumerState<_ManagerSelectSheet> createState() => _ManagerSelectSheetState();
}

class _ManagerSelectSheetState extends ConsumerState<_ManagerSelectSheet> {
  int? _selected;
  List<ManagerOption> _managers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadManagers());
  }

  Future<void> _loadManagers() async {
    final api = ref.read(remoteApiServiceProvider);
    final managers = await api.getManagers();
    if (!mounted) return;
    setState(() {
      _managers = managers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Хэндл + заголовок ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 36, height: 36),
                      Expanded(
                        child: Text(
                          context.l10n.t('chooseManager'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.secondaryText,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // ── Скроллируемый список ───────────────────────────────────────
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shrinkWrap: true,
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_managers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        context.l10n.t('managersNotFound'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    )
                  else
                    ..._managers.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = e.key),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selected == e.key
                                ? AppColors.iconBgBlue
                                : AppColors.primaryBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selected == e.key
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: _selected == e.key ? 1.5 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(e.value.initials,
                                      style: GoogleFonts.manrope(
                                          fontSize: 14, fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.value.name,
                                        style: GoogleFonts.manrope(
                                            fontSize: 15, fontWeight: FontWeight.w600,
                                            color: AppColors.primaryText)),
                                    Text(e.value.role,
                                        style: GoogleFonts.manrope(
                                            fontSize: 12, color: AppColors.secondaryText)),
                                  ],
                                ),
                              ),
                              if (_selected == e.key)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    )),
                ],
              ),
            ),
            // ── Кнопка подтверждения ───────────────────────────────────────
            const Divider(height: 1, thickness: 0.7, color: AppColors.divider),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 24),
              child: ElevatedButton(
                onPressed: _selected == null || _managers.isEmpty
                    ? null
                    : () => Navigator.pop(context, _managers[_selected!].name),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(context.l10n.t('done'),
                    style: GoogleFonts.manrope(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
