import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/utils/swallowed.dart';
import 'package:lima/features/knowledge/domain/repositories/drug_catalogue_repository.dart';

import '../../domain/entities/pharmacy_order.dart';
import '../../domain/repositories/pharmacy_order_draft_repository.dart';
import '../../domain/use_cases/build_pharmacy_order_lines.dart';
import '../../domain/use_cases/submit_pharmacy_order.dart';

enum PharmacyOrderSubmissionStatus {
  idle,
  loading,
  sent,
  queued,
  rejected,
  noPriceMatrix,
  invalidLines,
  failed,
}

class PharmacyOrderSubmissionState {
  final PharmacyOrderSubmissionStatus status;
  final int skippedInvalidItems;
  final String? message;
  final bool remoteError;

  const PharmacyOrderSubmissionState({
    this.status = PharmacyOrderSubmissionStatus.idle,
    this.skippedInvalidItems = 0,
    this.message,
    this.remoteError = false,
  });

  bool get isBusy => status == PharmacyOrderSubmissionStatus.loading;
}

class PharmacyOrderSubmitContext {
  final int orderUserId;
  final String? medicalRepName;
  final int? userCompanyId;
  final int? organizationInn;
  final bool isOffline;
  final String comment;

  const PharmacyOrderSubmitContext({
    required this.orderUserId,
    required this.medicalRepName,
    required this.userCompanyId,
    required this.organizationInn,
    required this.isOffline,
    required this.comment,
  });
}

class PharmacyOrderViewModelConfig {
  final int pharmacyId;
  final String organizationName;
  final bool fromCart;
  final int? checkoutCartId;
  final int prepaymentPercent;
  final int buyerType;
  final int? selectedCompanyId;
  final int? paymentVariantId;
  final int? marginId;
  final int? marginPercent;
  final Map<int, int> initialQuantities;
  final Map<int, Drug> initialDrugs;
  final List<CartItemSnapshot> cartItems;

  const PharmacyOrderViewModelConfig({
    required this.pharmacyId,
    this.organizationName = '',
    required this.fromCart,
    required this.checkoutCartId,
    required this.prepaymentPercent,
    required this.buyerType,
    this.selectedCompanyId,
    this.paymentVariantId,
    this.marginId,
    this.marginPercent,
    required this.initialQuantities,
    required this.initialDrugs,
    required this.cartItems,
  });

  bool cartItemBelongsToCurrentOrder(CartItemSnapshot item) {
    if (checkoutCartId != null && item.cartId != checkoutCartId) return false;
    if (item.pharmacyId != pharmacyId) return false;
    if ((item.prepaymentPercent ?? 100) != prepaymentPercent) return false;
    return (item.buyerType ?? 0) == buyerType;
  }
}

class PharmacyOrderViewState {
  final Map<int, Drug> drugs;
  final Map<int, int> quantities;
  final String query;
  final bool isLoading;
  final bool isConfirming;
  final bool isActionLocked;
  final String? error;
  final PharmacyOrderSubmissionState submission;

  const PharmacyOrderViewState({
    this.drugs = const {},
    this.quantities = const {},
    this.query = '',
    this.isLoading = false,
    this.isConfirming = false,
    this.isActionLocked = false,
    this.error,
    this.submission = const PharmacyOrderSubmissionState(),
  });

  List<int> get selectedIds => quantities.entries
      .where((entry) => entry.value > 0)
      .map((entry) => entry.key)
      .toList(growable: false);

  double get total => selectedIds.fold<double>(0, (sum, id) {
    final drug = drugs[id];
    return sum + (drug?.price ?? 0) * (quantities[id] ?? 0);
  });

  bool get hasInvalidQuantities => selectedIds.any(isOverStock);

  bool isOverStock(int id) {
    final drug = drugs[id];
    if (drug == null) return false;
    return (quantities[id] ?? 0) > availableStock(drug);
  }

  bool canIncrease(int id) {
    final drug = drugs[id];
    if (drug == null) return false;
    return (quantities[id] ?? 0) < availableStock(drug);
  }

  static int availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  PharmacyOrderViewState copyWith({
    Map<int, Drug>? drugs,
    Map<int, int>? quantities,
    String? query,
    bool? isLoading,
    bool? isConfirming,
    bool? isActionLocked,
    String? error,
    bool clearError = false,
    PharmacyOrderSubmissionState? submission,
  }) {
    return PharmacyOrderViewState(
      drugs: drugs ?? this.drugs,
      quantities: quantities ?? this.quantities,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isConfirming: isConfirming ?? this.isConfirming,
      isActionLocked: isActionLocked ?? this.isActionLocked,
      error: clearError ? null : (error ?? this.error),
      submission: submission ?? this.submission,
    );
  }
}

class PharmacyOrderViewModel extends StateNotifier<PharmacyOrderViewState> {
  final DrugCatalogueRepository _repository;
  final SubmitPharmacyOrder _submitPharmacyOrder;
  final PharmacyOrderDraftRepository _draftRepository;
  final PharmacyOrderViewModelConfig config;

  PharmacyOrderViewModel(
    this._repository,
    this._submitPharmacyOrder,
    this._draftRepository,
    this.config, {
    bool autoLoad = true,
  }) : super(
         PharmacyOrderViewState(
           drugs: Map.unmodifiable(config.initialDrugs),
           quantities: Map.unmodifiable(config.initialQuantities),
         ),
       ) {
    if (autoLoad) unawaited(load());
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final merged = {...state.drugs};

    if (config.fromCart) {
      for (final item in config.cartItems) {
        if (!config.cartItemBelongsToCurrentOrder(item) ||
            !state.quantities.containsKey(item.drugId)) {
          continue;
        }
        merged[item.drugId] = Drug(
          id: item.drugId,
          name: item.name,
          manufacturer: item.manufacturer,
          price: item.price,
          serialNumber: item.serialNumber,
          expiryDate: item.expiryDate,
          stock: item.stock,
          currentStockId: item.currentStockId,
          bindingDrugId: item.bindingDrugId,
        );
      }
    }
    state = state.copyWith(drugs: Map.unmodifiable(merged));

    try {
      final loaded = await _repository.getOrderDrugs();
      if (!mounted) return;
      for (final incoming in loaded) {
        final belongsToCatalog =
            !config.fromCart &&
            incoming.currentStockId != null &&
            incoming.bindingDrugId != null;
        final belongsToCart =
            config.fromCart && state.quantities.containsKey(incoming.id);
        if (!belongsToCatalog && !belongsToCart) continue;
        final existing = merged[incoming.id];
        merged[incoming.id] = _mergeDrug(incoming, existing);
      }
      state = state.copyWith(drugs: Map.unmodifiable(merged), isLoading: false);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }

  void increment(int id) {
    if (!state.canIncrease(id)) return;
    final quantities = {...state.quantities};
    quantities[id] = (quantities[id] ?? 0) + 1;
    state = state.copyWith(quantities: Map.unmodifiable(quantities));
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void setConfirming(bool value) => state = state.copyWith(isConfirming: value);

  void setActionLocked(bool value) =>
      state = state.copyWith(isActionLocked: value);

  void setQuantity(int id, int quantity) {
    final next = {...state.quantities};
    if (quantity <= 0) {
      next.remove(id);
    } else {
      next[id] = quantity;
    }
    state = state.copyWith(quantities: Map.unmodifiable(next));
  }

  void decrement(int id) {
    final current = state.quantities[id] ?? 0;
    final quantities = {...state.quantities};
    if (current <= 1) {
      quantities.remove(id);
    } else {
      quantities[id] = current - 1;
    }
    state = state.copyWith(quantities: Map.unmodifiable(quantities));
  }

  PharmacyOrderLinesResult buildSelectedLines() {
    final cartById = config.fromCart
        ? {
            for (final item in config.cartItems.where(
              config.cartItemBelongsToCurrentOrder,
            ))
              item.drugId: item,
          }
        : const <int, CartItemSnapshot>{};
    final lineInputs = state.selectedIds.map((id) {
      final drug = state.drugs[id];
      if (drug == null) return null;
      final quantity = state.quantities[id] ?? 0;
      if (quantity <= 0) return null;
      final cart = cartById[id];
      return PharmacyOrderLineInput(
        drugId: drug.id,
        drugName: drug.name,
        quantity: quantity,
        salePrice: drug.price,
        incomeDetailingId: cart?.currentStockId ?? drug.currentStockId,
        bindingDrugId: cart?.bindingDrugId ?? drug.bindingDrugId ?? drug.id,
        serialNumber: drug.serialNumber,
        expiryDate: drug.expiryDate,
      );
    }).whereType<PharmacyOrderLineInput>();
    return const BuildPharmacyOrderLines()(lineInputs);
  }

  Future<PharmacyOrderPricingPreview?> calculateSelectedPricing({
    int? companyId,
  }) async {
    final lines = buildSelectedLines();
    if (lines.lines.isEmpty) return null;
    return _submitPharmacyOrder.calculatePricing(
      prepaymentPercent: config.prepaymentPercent,
      isWholesaler: config.buyerType == 1,
      companyId: companyId,
      orderTotal: state.total,
      lines: lines.lines,
    );
  }

  Future<PharmacyOrderSubmissionState> submitOrder(
    PharmacyOrderSubmitContext context,
  ) async {
    if (state.submission.isBusy) return state.submission;
    _setSubmission(
      const PharmacyOrderSubmissionState(
        status: PharmacyOrderSubmissionStatus.loading,
      ),
    );

    final orderLinesResult = buildSelectedLines();
    if (orderLinesResult.lines.isEmpty) {
      return _finishSubmission(
        PharmacyOrderSubmissionState(
          status: PharmacyOrderSubmissionStatus.invalidLines,
          skippedInvalidItems: orderLinesResult.skippedInvalidItems,
        ),
      );
    }

    var orderLines = orderLinesResult.lines;
    PharmacyOrderPricingTerms? pricingTerms;
    var pricesAlreadyCalculated = config.marginId != null;
    if (!context.isOffline) {
      if (config.marginId != null) {
        pricingTerms = PharmacyOrderPricingTerms(
          companyId: config.selectedCompanyId ?? context.userCompanyId,
          paymentVariantId: config.paymentVariantId ?? 1,
          marginId: config.marginId!,
          marginPercent: config.marginPercent,
          prepaymentPercent: config.prepaymentPercent,
          isWholesaler: config.buyerType == 1,
        );
      } else {
        try {
          final pricingPreview = await _submitPharmacyOrder.calculatePricing(
            prepaymentPercent: config.prepaymentPercent,
            isWholesaler: config.buyerType == 1,
            companyId: context.userCompanyId,
            orderTotal: state.total,
            lines: orderLines,
          );
          pricingTerms = pricingPreview?.terms;
          if (pricingPreview != null) {
            orderLines = pricingPreview.lines;
            pricesAlreadyCalculated = true;
          }
        } catch (error) {
          logSwallowed(error, 'PharmacyOrderViewModel.calculatePricing');
        }
      }
      if (pricingTerms == null) {
        return _finishSubmission(
          const PharmacyOrderSubmissionState(
            status: PharmacyOrderSubmissionStatus.noPriceMatrix,
          ),
        );
      }
    }

    try {
      final draft = PharmacyOrderDraft(
        organizationId: config.pharmacyId,
        organizationName: config.organizationName,
        organizationInn: context.organizationInn,
        orderUserId: context.orderUserId,
        medicalRepName: context.medicalRepName,
        createdAt: DateTime.now(),
        comment: context.comment,
        prepaymentPercent: config.prepaymentPercent,
        buyerType: config.buyerType,
        isWholesaler: config.buyerType == 1,
        pricingTerms: pricingTerms,
        lines: orderLines,
      );
      final localId = await _draftRepository.saveDraft(draft);

      if (context.isOffline) {
        return _finishSubmission(
          PharmacyOrderSubmissionState(
            status: PharmacyOrderSubmissionStatus.queued,
            skippedInvalidItems: orderLinesResult.skippedInvalidItems,
          ),
        );
      }

      try {
        final submissionResult = await _submitPharmacyOrder.submitResult(
          orderUserId: context.orderUserId,
          organizationId: config.pharmacyId,
          pricingTerms: pricingTerms!,
          isWholesaler: config.buyerType == 1,
          orderComment: context.comment,
          lines: orderLines,
          pricesAlreadyCalculated: pricesAlreadyCalculated,
        );
        if (submissionResult.isFailure) {
          final original =
              submissionResult.failure is PharmacyOrderSubmissionFailure
              ? submissionResult.failure
              : submissionResult.failure?.cause;
          if (original is PharmacyOrderSubmissionFailure) {
            await _draftRepository.recordSubmissionFailure(
              localVisitId: localId,
              failure: original,
            );
            return _finishSubmission(
              PharmacyOrderSubmissionState(
                status: original.isPermanent
                    ? PharmacyOrderSubmissionStatus.rejected
                    : PharmacyOrderSubmissionStatus.queued,
                skippedInvalidItems: orderLinesResult.skippedInvalidItems,
                message: original.message,
                remoteError: !original.isPermanent,
              ),
            );
          }
          throw submissionResult.failure!;
        }
        final submission = submissionResult.requireValue;
        await _draftRepository.markSubmitted(
          localVisitId: localId,
          submission: submission,
          pricingTerms: pricingTerms,
          prepaymentPercent: config.prepaymentPercent,
          buyerType: config.buyerType,
          isWholesaler: config.buyerType == 1,
        );
        return _finishSubmission(
          PharmacyOrderSubmissionState(
            status: PharmacyOrderSubmissionStatus.sent,
            skippedInvalidItems: orderLinesResult.skippedInvalidItems,
          ),
        );
      } on PharmacyOrderSubmissionFailure catch (failure) {
        await _draftRepository.recordSubmissionFailure(
          localVisitId: localId,
          failure: failure,
        );
        return _finishSubmission(
          PharmacyOrderSubmissionState(
            status: failure.isPermanent
                ? PharmacyOrderSubmissionStatus.rejected
                : PharmacyOrderSubmissionStatus.queued,
            skippedInvalidItems: orderLinesResult.skippedInvalidItems,
            message: failure.message,
            remoteError: !failure.isPermanent,
          ),
        );
      }
    } catch (error) {
      return _finishSubmission(
        PharmacyOrderSubmissionState(
          status: PharmacyOrderSubmissionStatus.failed,
          message: '$error',
        ),
      );
    }
  }

  PharmacyOrderSubmissionState _finishSubmission(
    PharmacyOrderSubmissionState next,
  ) {
    _setSubmission(next);
    return next;
  }

  void _setSubmission(PharmacyOrderSubmissionState submission) {
    if (mounted) state = state.copyWith(submission: submission);
  }

  static Drug _mergeDrug(Drug incoming, Drug? existing) {
    return Drug(
      id: incoming.id,
      name: incoming.name,
      manufacturer: incoming.manufacturer,
      serialNumber: incoming.serialNumber ?? existing?.serialNumber,
      expiryDate: incoming.expiryDate ?? existing?.expiryDate,
      price: incoming.price > 0 ? incoming.price : (existing?.price ?? 0),
      mainStock: incoming.mainStock ?? existing?.mainStock,
      stock: incoming.stock ?? existing?.stock,
      remainsStock: incoming.remainsStock ?? existing?.remainsStock,
      documentsCount: incoming.documentsCount,
      currentStockId: incoming.currentStockId ?? existing?.currentStockId,
      bindingDrugId: incoming.bindingDrugId ?? existing?.bindingDrugId,
    );
  }
}
