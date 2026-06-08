import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/app_collections_provider.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/services/specification_export_service.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

class NewBronScreen extends ConsumerStatefulWidget {
  final int pharmacyId;
  final String pharmacyName;
  final bool isCheckoutMode;
  final Map<String, dynamic>? checkoutPayload;

  const NewBronScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
    this.isCheckoutMode = false,
    this.checkoutPayload,
  });

  @override
  ConsumerState<NewBronScreen> createState() => _NewBronScreenState();
}

class _NewBronScreenState extends ConsumerState<NewBronScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  final Map<int, int> _qtyByDrugId = {};
  final Map<int, Drug> _drugById = {};

  int _prepayment = 100;
  int _buyerType = 0;
  int? _companyId;
  int? _paymentVariantId;
  int? _marginId;
  int? _marginPercent;
  int? _checkoutCartId;
  bool _fromCart = false;
  bool _paramsLoaded = false;
  bool _actionLocked = false;
  final _specExport = SpecificationExportService();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paramsLoaded) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    final checkoutPayload = widget.checkoutPayload;
    _prepayment =
        _parseInt(checkoutPayload?['prepayment']) ??
        int.tryParse(params['prepayment'] ?? '') ??
        100;
    _buyerType =
        _parseInt(checkoutPayload?['buyerType']) ??
        int.tryParse(params['buyerType'] ?? '') ??
        0;
    _checkoutCartId =
        _parseInt(checkoutPayload?['cart_id']) ??
        int.tryParse(params['cart_id'] ?? '');
    _companyId =
        _parseInt(checkoutPayload?['companyId']) ??
        int.tryParse(params['companyId'] ?? '');
    _paymentVariantId =
        _parseInt(checkoutPayload?['paymentVariantId']) ??
        int.tryParse(params['paymentVariantId'] ?? '');
    _marginId =
        _parseInt(checkoutPayload?['marginId']) ??
        int.tryParse(params['marginId'] ?? '');
    _marginPercent =
        _parseInt(checkoutPayload?['marginPercent']) ??
        int.tryParse(params['marginPercent'] ?? '');
    _fromCart = widget.isCheckoutMode || params['from_cart'] == '1';
    final rawItems =
        checkoutPayload?['items']?.toString() ?? params['items'] ?? '';
    final rawItemsData = params['items_data'];
    for (final pair in rawItems.split(';')) {
      if (pair.isEmpty || !pair.contains(':')) continue;
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final id = int.tryParse(parts[0]);
      final qty = int.tryParse(parts[1]);
      if (id != null && qty != null && qty > 0) {
        _qtyByDrugId[id] = qty;
      }
    }
    final itemsData = checkoutPayload?['items_data'] ?? rawItemsData;
    if (itemsData != null && (itemsData is! String || itemsData.isNotEmpty)) {
      try {
        final decoded = itemsData is String ? jsonDecode(itemsData) : itemsData;
        if (decoded is List) {
          for (final row in decoded) {
            if (row is! Map) continue;
            final m = Map<String, dynamic>.from(row);
            final id = (m['id'] as num?)?.toInt();
            if (id == null) continue;
            _drugById[id] = Drug(
              id: id,
              name: (m['name'] as String?) ?? 'Препарат #$id',
              manufacturer: (m['manufacturer'] as String?) ?? '',
              price: ((m['sale_price'] as num?) ?? (m['price'] as num?) ?? 0)
                  .toDouble(),
              serialNumber: m['serial_number'] as String?,
              expiryDate: m['expiry_date'] as String?,
              mainStock: (m['main_stock'] as num?)?.toInt(),
              stock: (m['stock'] as num?)?.toInt(),
              remainsStock: (m['remains_stock'] as num?)?.toInt(),
              currentStockId: (m['current_stock_id'] as num?)?.toInt(),
              bindingDrugId: (m['binding_drug_id'] as num?)?.toInt(),
            );
          }
        }
      } catch (_) {}
    }
    _paramsLoaded = true;
    _loadDrugs();
  }

  Future<void> _loadDrugs() async {
    final db = ref.read(localDatabaseProvider);

    // Seed from cart snapshot first so items show immediately even if DB lookup
    // returns a different ID space (price-list binding IDs vs dict drug IDs).
    if (_fromCart) {
      final cartItems = ref
          .read(appCollectionsProvider)
          .cartItems
          .where(_cartItemBelongsToCurrentOrder);
      for (final item in cartItems) {
        if (_qtyByDrugId.containsKey(item.drugId)) {
          _drugById[item.drugId] = Drug(
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
      if (mounted) setState(() {});
    }

    final rows = await db.getDrugs();
    final next = <int, Drug>{};
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id == null || !_qtyByDrugId.containsKey(id)) continue;
      next[id] = Drug(
        id: id,
        name: (row['name'] as String?) ?? '—',
        manufacturer: (row['manufacturer'] as String?) ?? '',
        serialNumber: row['serial_number'] as String?,
        expiryDate: row['expiry_date'] as String?,
        price: ((row['price'] as num?) ?? 0).toDouble(),
        mainStock: (row['main_stock'] as num?)?.toInt(),
        stock: row['stock'] as int?,
        remainsStock: (row['remains_stock'] as num?)?.toInt(),
        currentStockId: (row['current_stock_id'] as num?)?.toInt(),
        bindingDrugId: (row['binding_drug_id'] as num?)?.toInt(),
      );
    }
    if (!mounted) return;
    setState(() {
      // Merge: DB results override cart snapshot data, but don't wipe entries
      // that exist in the snapshot but are absent from the DB (different ID space).
      for (final entry in next.entries) {
        final id = entry.key;
        final incoming = entry.value;
        final existing = _drugById[id];
        _drugById[id] = Drug(
          id: incoming.id,
          name: incoming.name,
          manufacturer: incoming.manufacturer,
          serialNumber: incoming.serialNumber ?? existing?.serialNumber,
          expiryDate: incoming.expiryDate ?? existing?.expiryDate,
          price: incoming.price > 0 ? incoming.price : (existing?.price ?? 0),
          mainStock: incoming.mainStock ?? existing?.mainStock,
          stock: incoming.stock ?? existing?.stock,
          remainsStock: incoming.remainsStock ?? existing?.remainsStock,
          currentStockId: incoming.currentStockId ?? existing?.currentStockId,
          bindingDrugId: incoming.bindingDrugId ?? existing?.bindingDrugId,
        );
      }
    });
  }

  List<int> get _ids =>
      _qtyByDrugId.entries.where((e) => e.value > 0).map((e) => e.key).toList();
  bool get _hasInvalidQuantities => _ids.any((id) {
    final drug = _drugById[id];
    if (drug == null) return false;
    return _isOverStock(drug, _qtyByDrugId[id] ?? 0);
  });

  double get _total {
    var sum = 0.0;
    for (final id in _ids) {
      final drug = _drugById[id];
      if (drug == null) continue;
      sum += (drug.price * (_qtyByDrugId[id] ?? 0));
    }
    return sum;
  }

  Future<void> _saveToCart() async {
    if (_actionLocked) return;
    if (_hasInvalidQuantities) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Количество больше доступного остатка')),
      );
      return;
    }
    setState(() => _actionLocked = true);
    final notifier = ref.read(appCollectionsProvider.notifier);
    var savedCount = 0;
    for (final id in _ids) {
      final qty = _qtyByDrugId[id] ?? 0;
      if (qty <= 0) continue;
      final drug = _drugById[id];
      if (drug == null) continue;
      await notifier.addToCart(
        drug,
        quantity: qty,
        pharmacyId: widget.pharmacyId,
        pharmacyName: widget.pharmacyName,
        prepaymentPercent: _prepayment,
        buyerType: _buyerType,
      );
      savedCount++;
    }
    if (savedCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подождите, загружаются данные препаратов'),
          ),
        );
      }
      if (mounted) setState(() => _actionLocked = false);
      return;
    }
    if (!mounted) return;
    await _showResultDialog(
      title: 'Заказ добавлен в корзину',
      subtitle: 'Ваш заказ успешно сохранен в корзине',
      badge: 'Заказ будет доступен 12 часов',
    );
  }

  Future<void> _sendOrder() async {
    if (_actionLocked) return;
    if (_hasInvalidQuantities) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Количество больше доступного остатка')),
      );
      return;
    }
    setState(() => _actionLocked = true);
    final now = DateTime.now().toIso8601String();

    // Build drugs payload using income_detailing_id (= current_stock_id from
    // price-list) so the backend creates a proper Бронь order, not a presentation.
    final cartItems = _fromCart
        ? ref
              .read(appCollectionsProvider)
              .cartItems
              .where(_cartItemBelongsToCurrentOrder)
        : <CartItemSnapshot>[];
    final cartById = {for (final c in cartItems) c.drugId: c};

    var skippedInvalidItems = 0;
    final itemsPayload = _ids
        .map((id) {
          final drug = _drugById[id];
          if (drug == null) return null;
          final qty = _qtyByDrugId[id] ?? 0;
          if (qty <= 0) return null;
          final cart = cartById[id];
          // income_detailing_id comes from cart snapshot (server cart) or drug model
          final incomeDetailingId = cart?.currentStockId ?? drug.currentStockId;
          final bindingDrugId =
              cart?.bindingDrugId ?? drug.bindingDrugId ?? drug.id;
          // For pharmacy orders backend expects a stock binding pair.
          // Without income_detailing_id the visit can be saved as "Нет заказов".
          if (incomeDetailingId == null || bindingDrugId <= 0) {
            skippedInvalidItems++;
            return null;
          }
          return <String, dynamic>{
            'income_detailing_id': incomeDetailingId,
            'drug_id': bindingDrugId,
            'drug_name': drug.name,
            'package': qty,
            'quantity': qty,
            'sale_price': drug.price,
            'sale_price_without_nds': _priceWithoutNds(drug.price),
            'price': drug.price,
            'serial_no': drug.serialNumber,
            'expire_date': drug.expiryDate,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    if (itemsPayload.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подождите, загружаются данные препаратов'),
          ),
        );
      }
      if (mounted) setState(() => _actionLocked = false);
      return;
    }

    int? localId;
    var remoteSynced = false;
    var remoteError = false;
    var remoteRejected = false;
    String? remoteRejectMessage;
    try {
      final isOffline = ref.read(isOfflineProvider);
      final isWholesaler = _buyerType == 1;
      final user = ref.read(authProvider).user;
      final orderUserId = user?.id;
      if (orderUserId == null || orderUserId <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось определить пользователя')),
          );
        }
        if (mounted) setState(() => _actionLocked = false);
        return;
      }

      final db = ref.read(localDatabaseProvider);
      final api = ref.read(remoteApiServiceProvider);
      final org = await db.getOrganisationById(widget.pharmacyId);
      final organizationInn = _parseInt(org?['inn']);

      Map<String, dynamic>? pricingTerms;
      if (!isOffline) {
        if (_marginId != null) {
          pricingTerms = {
            'company_id': _companyId ?? user?.companyId,
            'payment_variant_id': _paymentVariantId ?? 1,
            'margin_id': _marginId,
            'margin_percent': _marginPercent,
            'prepayment_percent': _prepayment,
            'is_wholesaler': isWholesaler,
          };
        } else {
          try {
            pricingTerms = await api.resolveOrderPricingTerms(
              prepaymentPercent: _prepayment,
              isWholesaler: isWholesaler,
              orderTotal: _total,
              companyId: user?.companyId,
            );
          } catch (_) {
            pricingTerms = null;
          }
        }
        if (pricingTerms == null) {
          if (mounted) {
            final buyerLabel = isWholesaler ? 'Опт' : 'Розница';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'В API нет ценовой матрицы для $_prepayment% / $buyerLabel',
                ),
              ),
            );
          }
          if (mounted) setState(() => _actionLocked = false);
          return;
        }
      }
      final rawVisitJson = jsonEncode({
        'organization_id': widget.pharmacyId,
        'organization_name': widget.pharmacyName,
        'organization_inn': organizationInn,
        'visit_type': 1,
        'status': 'completed',
        'comment': _commentCtrl.text.trim(),
        'order_comment': _commentCtrl.text.trim(),
        'order_user_id': orderUserId,
        'prepayment': _prepayment,
        'prepayment_percent': _prepayment,
        'buyer_type': _buyerType,
        'is_wholesaler': isWholesaler,
        if (pricingTerms?['company_id'] != null)
          'company_id': pricingTerms!['company_id'],
        if (pricingTerms?['payment_variant_id'] != null)
          'payment_variant_id': pricingTerms!['payment_variant_id'],
        if (pricingTerms?['margin_id'] != null)
          'margin_id': pricingTerms!['margin_id'],
        if (pricingTerms?['margin_percent'] != null)
          'margin_percent': pricingTerms!['margin_percent'],
        // Backend web contract sends pharmacy booking lines in Visits/add.drugs.
        'drugs': itemsPayload,
        // Keep legacy key for backward compatibility with local readers.
        'items': itemsPayload,
        'start_date': now,
        'end_date': now,
      });
      localId = await db.insertVisit({
        'remote_id': null,
        'org_id': widget.pharmacyId,
        'org_name': widget.pharmacyName,
        'doctor_id': null,
        'doctor_name': null,
        'visit_type': 'order',
        'status': 'completed',
        'notes': _commentCtrl.text.trim(),
        'medical_rep_name': user?.fullName,
        'created_at': now,
        'updated_at': now,
        'raw_json': rawVisitJson,
      });
      ref.invalidate(dashboardCountsProvider);
      if (!isOffline) {
        try {
          final pushResult = await api.createOrderVisitDebug(
            orderUserId: orderUserId,
            organizationId: widget.pharmacyId,
            companyId: _parseInt(pricingTerms?['company_id']),
            paymentVariantId: _parseInt(pricingTerms?['payment_variant_id']),
            marginId: _parseInt(pricingTerms?['margin_id']),
            marginPercent: _parseInt(pricingTerms?['margin_percent']),
            prepaymentPercent: _prepayment,
            isWholesaler: isWholesaler,
            orderComment: _commentCtrl.text.trim(),
            drugs: itemsPayload,
            pricesAlreadyCalculated: _marginId != null,
          );
          await db.markSynced([localId]);
          remoteSynced = true;
          final responseObj = pushResult['response'];
          final remoteId = switch (responseObj) {
            int v => v,
            String s => int.tryParse(s),
            Map<String, dynamic> m =>
              (m['visit_id'] as num?)?.toInt() ??
                  (m['id'] as num?)?.toInt() ??
                  (m['data'] is Map<String, dynamic>
                      ? ((m['data']['visit_id'] as num?)?.toInt() ??
                            (m['data']['id'] as num?)?.toInt())
                      : null),
            _ => null,
          };
          if (remoteId != null) {
            await db.updateVisitRemoteId(
              localVisitId: localId,
              remoteId: remoteId,
            );
            // Replace local request payload with canonical server history payload
            // so UI details (e.g. serial_no, computed sums) match agent view.
            try {
              final remoteRow = await api.getVisitHistoryOrderById(remoteId);
              if (remoteRow != null) {
                final remoteRaw = remoteRow['raw_json'] is String
                    ? remoteRow['raw_json'] as String
                    : jsonEncode(remoteRow);
                final serverRaw = _mergeSelectedOrderTerms(
                  remoteRaw,
                  prepayment: _prepayment,
                  buyerType: _buyerType,
                  isWholesaler: isWholesaler,
                  pricingTerms: pricingTerms,
                );
                await db.updateVisitRawJson(
                  localVisitId: localId,
                  rawJson: serverRaw,
                );
              }
            } catch (_) {}
          }
          await db.setVisitPushPayload(
            visitId: localId,
            requestJson: jsonEncode(pushResult['request']),
            responseJson: jsonEncode(pushResult['response']),
          );
        } catch (e) {
          if (isPermanentVisitPushFailure(e)) {
            remoteRejected = true;
            remoteRejectMessage = e is RemotePushException
                ? e.displayMessage
                : 'Сервер отклонил заказ';
            await db.deleteVisit(localId);
            ref.invalidate(dashboardCountsProvider);
          } else {
            remoteError = true;
            final requestJson = e is RemotePushException
                ? jsonEncode(e.request)
                : null;
            final responseJson = e is RemotePushException
                ? jsonEncode(e.response)
                : jsonEncode({'error': '$e'});
            await db.setVisitPushPayload(
              visitId: localId,
              requestJson: requestJson,
              responseJson: responseJson,
            );
            // Keep local visit unsynced for background reconciliation.
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось оформить заказ: $e')),
        );
        setState(() => _actionLocked = false);
      }
      return;
    }

    if (remoteRejected) {
      if (!mounted) return;
      await _showResultDialog(
        title: 'Заказ не создан',
        subtitle:
            remoteRejectMessage ?? 'Сервер отклонил заказ, он не сохранён',
        success: false,
        stayOnPageOnClose: true,
      );
      return;
    }

    if (skippedInvalidItems > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Пропущено позиций без остатков: $skippedInvalidItems'),
        ),
      );
    }

    if (_fromCart) {
      unawaited(
        ref
            .read(appCollectionsProvider.notifier)
            .clearCartGroup(
              pharmacyId: widget.pharmacyId,
              pharmacyName: widget.pharmacyName,
              cartId: _checkoutCartId,
              prepaymentPercent: _prepayment,
              buyerType: _buyerType,
            )
            .catchError((_) {}),
      );
    }
    ref.invalidate(dashboardCountsProvider);
    if (ref.read(isOfflineProvider)) {
      pulseOfflineBanner(ref);
    }
    unawaited(
      ref.read(authProvider.notifier).refreshProfile().catchError((_) {}),
    );
    if (!mounted) return;
    await _showResultDialog(
      title: remoteSynced ? 'Заказ оформлен' : 'Заказ сохранен',
      subtitle: remoteSynced
          ? 'Ваш заказ успешно отправлен оператору'
          : remoteError
          ? 'Не удалось отправить на сервер. Заказ останется в очереди синхронизации'
          : 'Заказ будет отправлен при синхронизации',
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(RegExp(r'\D'), ''));
  }

  String _mergeSelectedOrderTerms(
    String rawJson, {
    required int prepayment,
    required int buyerType,
    required bool isWholesaler,
    Map<String, dynamic>? pricingTerms,
  }) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        map['prepayment'] = prepayment;
        map['prepayment_percent'] = prepayment;
        map['buyer_type'] = buyerType;
        map['is_wholesaler'] = isWholesaler;
        if (pricingTerms?['margin_id'] != null) {
          map['margin_id'] = pricingTerms!['margin_id'];
        }
        if (pricingTerms?['margin_percent'] != null) {
          map['margin_percent'] = pricingTerms!['margin_percent'];
        }
        if (pricingTerms?['payment_variant_id'] != null) {
          map['payment_variant_id'] = pricingTerms!['payment_variant_id'];
        }
        return jsonEncode(map);
      }
    } catch (_) {}
    return rawJson;
  }

  bool _cartItemBelongsToCurrentOrder(CartItemSnapshot item) {
    if (_checkoutCartId != null && item.cartId != _checkoutCartId) {
      return false;
    }
    if (item.pharmacyId != widget.pharmacyId) return false;
    final prepayment = item.prepaymentPercent ?? 100;
    if (prepayment != _prepayment) return false;
    final buyerType = item.buyerType ?? 0;
    if (buyerType != _buyerType) return false;
    return true;
  }

  int _availableStock(Drug drug) => drug.remainsStock ?? drug.stock ?? 0;

  bool _isOverStock(Drug drug, int qty) => qty > _availableStock(drug);

  bool _isLineOverStock(int id) {
    final drug = _drugById[id];
    if (drug == null) return false;
    return _isOverStock(drug, _qtyByDrugId[id] ?? 0);
  }

  bool _canIncreaseQty(int id) {
    final drug = _drugById[id];
    if (drug == null) return false;
    return (_qtyByDrugId[id] ?? 0) < _availableStock(drug);
  }

  double _priceWithoutNds(double value) {
    return double.parse((value / 1.12).toStringAsFixed(2));
  }

  Future<void> _showSpecFormatDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Выберите формат',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  AppTapScale(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final data = SpecificationData(
                    orderId: DateTime.now().millisecondsSinceEpoch % 100000,
                    date: DateTime.now(),
                    seller: 'LIMA',
                    buyer: widget.pharmacyName,
                    items: _ids
                        .map(
                          (id) => SpecificationItem(
                            name: _drugById[id]?.name ?? '—',
                            manufacturer: _drugById[id]?.manufacturer ?? '',
                            quantity: _qtyByDrugId[id] ?? 1,
                            serialNumber: _drugById[id]?.serialNumber ?? '—',
                            expiryDate: _drugById[id]?.expiryDate ?? '—',
                            basePrice: (_drugById[id]?.price ?? 0) / 1.2,
                          ),
                        )
                        .toList(),
                  );
                  _specExport.export(
                    context,
                    data: data,
                    format: SpecificationFormat.xlsx,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Excel (.xlsx)',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final data = SpecificationData(
                    orderId: DateTime.now().millisecondsSinceEpoch % 100000,
                    date: DateTime.now(),
                    seller: 'LIMA',
                    buyer: widget.pharmacyName,
                    items: _ids
                        .map(
                          (id) => SpecificationItem(
                            name: _drugById[id]?.name ?? '—',
                            manufacturer: _drugById[id]?.manufacturer ?? '',
                            quantity: _qtyByDrugId[id] ?? 1,
                            serialNumber: _drugById[id]?.serialNumber ?? '—',
                            expiryDate: _drugById[id]?.expiryDate ?? '—',
                            basePrice: (_drugById[id]?.price ?? 0) / 1.2,
                          ),
                        )
                        .toList(),
                  );
                  _specExport.export(
                    context,
                    data: data,
                    format: SpecificationFormat.png,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Изображение (.png)',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showResultDialog({
    required String title,
    required String subtitle,
    String? badge,
    bool success = true,
    bool stayOnPageOnClose = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !success,
      builder: (ctx) => PopScope(
        canPop: !success,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!success)
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppTapScale(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.secondaryText,
                        size: 22,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Center(
                    child: Icon(
                      success ? Icons.check_rounded : Icons.close_rounded,
                      color: success
                          ? const Color(0xFF4AAE7E)
                          : const Color(0xFFE05050),
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3DB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: const Color(0xFFE3A335),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (success) const SizedBox(height: 16),
                if (success)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.pushReplacement(
                        Uri(
                          path: '/visits/pharmacy/detail/${widget.pharmacyId}',
                          queryParameters: {'name': widget.pharmacyName},
                        ).toString(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Перейти к компании',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (success) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (!stayOnPageOnClose) {
                        context.go(
                          '/home?refresh=${DateTime.now().millisecondsSinceEpoch}',
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E6EE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      stayOnPageOnClose ? 'Понятно' : 'На главную',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsCount = _ids.fold<int>(
      0,
      (sum, id) => sum + (_qtyByDrugId[id] ?? 0),
    );
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
                AppTapScale(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else if (widget.isCheckoutMode) {
                      context.go('/basket');
                    } else {
                      context.go(
                        Uri(
                          path:
                              '/visits/pharmacy/detail/${widget.pharmacyId}/type',
                          queryParameters: {'name': widget.pharmacyName},
                        ).toString(),
                      );
                    }
                  },
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
                        widget.isCheckoutMode
                            ? 'Оформление заказа'
                            : 'Оформление брони',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
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
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                _orderDetailsCard(itemsCount),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: shadowSm,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _pair('Предоплата:', '$_prepayment%'),
                      const Divider(color: AppColors.divider, height: 16),
                      _pair(
                        'Тип покупателя:',
                        _buyerType == 1 ? 'Опт' : 'Розница',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: shadowSm,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Комментарий',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Введите комментарий...',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          boxShadow: shadowMd,
        ),
        padding: EdgeInsets.fromLTRB(
          8,
          8,
          8,
          MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE6894A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'К оплате:',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatUzs(_total),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _ids.isEmpty || _actionLocked || _hasInvalidQuantities
                  ? null
                  : _sendOrder,
              icon: _actionLocked
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _actionLocked
                    ? 'Оформляем заказ...'
                    : 'Отправить заказ оператору',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (!widget.isCheckoutMode) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed:
                    _ids.isEmpty || _actionLocked || _hasInvalidQuantities
                    ? null
                    : _saveToCart,
                icon: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Color(0xFF2C9E63),
                ),
                label: Text(
                  'Сохранить в корзину',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C9E63),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Color(0xFFAEDFC6)),
                  backgroundColor: const Color(0xFFEFFAF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _ids.isEmpty || _actionLocked || _hasInvalidQuantities
                  ? null
                  : _showSpecFormatDialog,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(
                'Скачать спецификацию',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderDetailsCard(int itemsCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadowSm,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.isCheckoutMode
                    ? 'Детализация заказа'
                    : 'Детализация брони',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$itemsCount шт.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final id in _ids) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isLineOverStock(id)
                      ? AppColors.error
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _drugById[id]?.name ?? 'Препарат #$id',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((_drugById[id]?.manufacturer ?? '').isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            _drugById[id]!.manufacturer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          '${formatUzs(_drugById[id]?.price ?? 0)} x ${_qtyByDrugId[id]} = ${formatUzs((_drugById[id]?.price ?? 0) * (_qtyByDrugId[id] ?? 0))}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.isCheckoutMode)
                    Text(
                      '${_qtyByDrugId[id] ?? 0} шт.',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isLineOverStock(id)
                            ? AppColors.error
                            : AppColors.secondaryText,
                      ),
                    )
                  else
                    Row(
                      children: [
                        _qtyButton(
                          icon: Icons.remove_rounded,
                          onTap: () => setState(() {
                            final next = (_qtyByDrugId[id] ?? 0) - 1;
                            if (next <= 0) {
                              _qtyByDrugId.remove(id);
                            } else {
                              _qtyByDrugId[id] = next;
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_qtyByDrugId[id] ?? 0}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isLineOverStock(id)
                                ? AppColors.error
                                : AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _qtyButton(
                          icon: Icons.add_rounded,
                          onTap: _canIncreaseQty(id)
                              ? () => setState(() {
                                  _qtyByDrugId[id] =
                                      (_qtyByDrugId[id] ?? 0) + 1;
                                })
                              : null,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _pair(String left, String right) {
    return Row(
      children: [
        Text(
          left,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
        const Spacer(),
        Text(
          right,
          style: GoogleFonts.manrope(
            fontSize: 18,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          color: AppColors.secondaryBg,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? AppColors.hintText : AppColors.secondaryText,
        ),
      ),
    );
  }
}
