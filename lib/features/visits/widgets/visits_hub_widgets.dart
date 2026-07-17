part of '../screens/visits_hub_screen.dart';

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedTypeSelector extends StatelessWidget {
  final bool isLpu;
  final ValueChanged<bool> onChanged;

  const _SegmentedTypeSelector({required this.isLpu, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / 2;
        return Container(
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: isLpu ? 0 : segmentWidth,
                top: 0,
                width: segmentWidth,
                height: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: shadowSm,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _TabBtn(
                      label: context.l10n.t('lpu'),
                      active: isLpu,
                      onTap: () => onChanged(true),
                    ),
                  ),
                  Expanded(
                    child: _TabBtn(
                      label: context.l10n.t('pharmacies'),
                      active: !isLpu,
                      onTap: () => onChanged(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
