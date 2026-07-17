part of '../screens/pharmacy/pharmacy_stock_screen.dart';

extension _PharmacyStockScreenUi on _PharmacyStockScreenState {
  Widget _buildScreen(BuildContext context) {
    final viewState = ref.watch(pharmacyStockViewModelProvider);
    final filtered = viewState.filteredDrugs;
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
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primaryText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('removeStockTitle'),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (widget.pharmacyName.isNotEmpty)
                        Text(
                          widget.pharmacyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              onChanged: (v) =>
                  ref.read(pharmacyStockViewModelProvider.notifier).setQuery(v),
              decoration: InputDecoration(
                hintText: context.l10n.t('searchDrugs'),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.hintText,
                  size: 20,
                ),
              ),
            ),
          ),
          Expanded(
            child: viewState.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : filtered.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.l10n.t('nothingFound'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final drug = filtered[i];
                      final qty = viewState.quantities[drug.id];
                      final isOverStock =
                          qty != null && viewState.isOverStock(drug, qty);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _openQtyDialog(drug),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBg,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: shadowSm,
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        drug.name,
                                        style: GoogleFonts.manrope(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.l10n.t(
                                          'manufacturerColon',
                                          args: {
                                            'value':
                                                drug.manufacturer.isNotEmpty
                                                ? drug.manufacturer
                                                : '—',
                                          },
                                        ),
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.l10n.t(
                                          'serialColon',
                                          args: {
                                            'value':
                                                drug.serialNumber?.isNotEmpty ==
                                                    true
                                                ? drug.serialNumber!
                                                : '—',
                                          },
                                        ),
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.l10n.t(
                                          'expiryColon',
                                          args: {
                                            'value':
                                                drug.expiryDate?.isNotEmpty ==
                                                    true
                                                ? drug.expiryDate!
                                                : '—',
                                          },
                                        ),
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Divider(
                                        height: 1,
                                        color: AppColors.divider,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        context.l10n.t(
                                          'priceColon',
                                          args: {
                                            'value': formatUzs(drug.price),
                                          },
                                        ),
                                        style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (qty != null && qty > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOverStock
                                          ? const Color(0xFFFFE8E8)
                                          : AppColors.iconBgBlue,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isOverStock
                                          ? Border.all(color: AppColors.error)
                                          : null,
                                    ),
                                    child: Text(
                                      '$qty',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isOverStock
                                            ? AppColors.error
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
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
      bottomNavigationBar: viewState.selectedCount > 0
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBg,
                boxShadow: shadowMd,
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 8,
              ),
              child: ElevatedButton(
                onPressed: viewState.hasInvalidSelectedQty
                    ? null
                    : _openConfirmScreen,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.t('continue'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
