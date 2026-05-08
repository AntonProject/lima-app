import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/api_client.dart';

const _favoritePharmacyIdsKey = 'favorite_pharmacy_ids';
const _cartItemsKey = 'cart_items';

class CartItemSnapshot {
  final int drugId;
  final String name;
  final String manufacturer;
  final double price;
  final String? serialNumber;
  final String? expiryDate;
  final int? stock;
  final int quantity;
  final int? pharmacyId;
  final String? pharmacyName;
  final String? addedAt;

  /// Stock position ID (income_detailing_id / current_stock_id from price-list).
  /// Required to create a proper Бронь order on the backend.
  final int? currentStockId;

  /// Binding-level drug ID (drug.id from drug_binding, not dict drug_id).
  final int? bindingDrugId;

  const CartItemSnapshot({
    required this.drugId,
    required this.name,
    required this.manufacturer,
    required this.price,
    this.serialNumber,
    this.expiryDate,
    this.stock,
    required this.quantity,
    this.pharmacyId,
    this.pharmacyName,
    this.addedAt,
    this.currentStockId,
    this.bindingDrugId,
  });

  double get total => price * quantity;

  CartItemSnapshot copyWith({int? quantity}) {
    return CartItemSnapshot(
      drugId: drugId,
      name: name,
      manufacturer: manufacturer,
      price: price,
      serialNumber: serialNumber,
      expiryDate: expiryDate,
      stock: stock,
      quantity: quantity ?? this.quantity,
      pharmacyId: pharmacyId,
      pharmacyName: pharmacyName,
      addedAt: addedAt,
      currentStockId: currentStockId,
      bindingDrugId: bindingDrugId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'drug_id': drugId,
      'name': name,
      'manufacturer': manufacturer,
      'price': price,
      'serial_number': serialNumber,
      'expiry_date': expiryDate,
      'stock': stock,
      'quantity': quantity,
      'pharmacy_id': pharmacyId,
      'pharmacy_name': pharmacyName,
      'added_at': addedAt,
      if (currentStockId != null) 'current_stock_id': currentStockId,
      if (bindingDrugId != null) 'binding_drug_id': bindingDrugId,
    };
  }

  factory CartItemSnapshot.fromJson(Map<String, dynamic> json) {
    return CartItemSnapshot(
      drugId: json['drug_id'] as int,
      name: json['name'] as String,
      manufacturer: json['manufacturer'] as String,
      price: (json['price'] as num).toDouble(),
      serialNumber: json['serial_number'] as String?,
      expiryDate: json['expiry_date'] as String?,
      stock: json['stock'] as int?,
      quantity: json['quantity'] as int? ?? 1,
      pharmacyId: json['pharmacy_id'] as int?,
      pharmacyName: json['pharmacy_name'] as String?,
      addedAt: json['added_at'] as String?,
      currentStockId: json['current_stock_id'] as int?,
      bindingDrugId: json['binding_drug_id'] as int?,
    );
  }

  factory CartItemSnapshot.fromDrug(
    Drug drug, {
    int quantity = 1,
    int? pharmacyId,
    String? pharmacyName,
    String? addedAt,
  }) {
    return CartItemSnapshot(
      drugId: drug.id,
      name: drug.name,
      manufacturer: drug.manufacturer,
      price: drug.price,
      serialNumber: drug.serialNumber,
      expiryDate: drug.expiryDate,
      stock: drug.stock,
      quantity: quantity,
      pharmacyId: pharmacyId,
      pharmacyName: pharmacyName,
      addedAt: addedAt,
      currentStockId: drug.currentStockId,
      bindingDrugId: drug.bindingDrugId,
    );
  }
}

class AppCollectionsState {
  final Set<int> favoritePharmacyIds;
  final List<CartItemSnapshot> cartItems;
  final bool isReady;

  /// Server-side cart ID (from GET /api/Cart response). Used to delete the
  /// server cart when the user submits or clears the order.
  final int? serverCartId;

  const AppCollectionsState({
    this.favoritePharmacyIds = const {},
    this.cartItems = const [],
    this.isReady = false,
    this.serverCartId,
  });

  int get cartCount => cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => cartItems.fold(0, (sum, item) => sum + item.total);

  AppCollectionsState copyWith({
    Set<int>? favoritePharmacyIds,
    List<CartItemSnapshot>? cartItems,
    bool? isReady,
    int? serverCartId,
    bool clearServerCartId = false,
  }) {
    return AppCollectionsState(
      favoritePharmacyIds: favoritePharmacyIds ?? this.favoritePharmacyIds,
      cartItems: cartItems ?? this.cartItems,
      isReady: isReady ?? this.isReady,
      serverCartId: clearServerCartId
          ? null
          : (serverCartId ?? this.serverCartId),
    );
  }
}

class AppCollectionsNotifier extends StateNotifier<AppCollectionsState> {
  final Ref _ref;
  final dynamic _prefs;

  AppCollectionsNotifier(this._ref, this._prefs)
    : super(const AppCollectionsState()) {
    _load();
  }

  Future<void> _load() async {
    final storedFavoriteIds = _prefs.getStringList(_favoritePharmacyIdsKey);
    final Set<int> favoritePharmacyIds =
        (storedFavoriteIds == null || storedFavoriteIds.isEmpty)
        ? <int>{}
        : storedFavoriteIds
              .map((id) => int.tryParse('$id'))
              .whereType<int>()
              .toSet();

    final storedCartItems = _prefs.getStringList(_cartItemsKey) ?? [];
    final cartItems = <CartItemSnapshot>[];
    for (final raw in storedCartItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          cartItems.add(CartItemSnapshot.fromJson(decoded));
          continue;
        }
        // Backward compatibility: a single entry may contain a JSON array.
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map<String, dynamic>) {
              cartItems.add(CartItemSnapshot.fromJson(e));
            }
          }
        }
      } catch (_) {
        // Ignore malformed legacy values and continue loading app state.
      }
    }

    final activeCartItems = _filterExpiredCart(cartItems);

    state = state.copyWith(
      favoritePharmacyIds: favoritePharmacyIds,
      cartItems: activeCartItems,
      isReady: true,
    );
    if (activeCartItems.length != cartItems.length) {
      await _persistCart(activeCartItems);
    }

    try {
      final api = _ref.read(remoteApiServiceProvider);
      final remoteFavorites = await api.getFavoriteOrganizations();
      final remoteIds = remoteFavorites
          .map((e) => e['id'])
          .whereType<int>()
          .toSet();
      final db = _ref.read(localDatabaseProvider);
      await db.clearOrgFavorites();
      for (final id in remoteIds) {
        await db.updateOrgFavorite(id, true);
      }
      state = state.copyWith(favoritePharmacyIds: remoteIds);
      await _persistFavorites(remoteIds);
    } catch (_) {
      // Keep local favorites when API is unavailable.
    }

    // Load server-side cart — overwrites local cache if server returns items.
    try {
      final api = _ref.read(remoteApiServiceProvider);
      final serverItems = await api.getServerCart();
      if (serverItems.isNotEmpty) {
        final cartItems = serverItems
            .map((e) => CartItemSnapshot.fromJson(e))
            .toList();
        // Extract the cart ID from the first item so we can delete it later.
        final cartId = serverItems.first['cart_id'] as int?;
        state = state.copyWith(cartItems: cartItems, serverCartId: cartId);
        await _persistCart(cartItems);
      }
    } catch (_) {
      // Keep local cart when API is unavailable (offline mode).
    }
  }

  Future<void> _persistFavorites(Set<int> ids) async {
    await _prefs.setStringList(
      _favoritePharmacyIdsKey,
      ids.map((id) => '$id').toList(),
    );
  }

  Future<void> _persistCart(List<CartItemSnapshot> items) async {
    await _prefs.setStringList(
      _cartItemsKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<bool> toggleFavoritePharmacy(int pharmacyId) async {
    final next = {...state.favoritePharmacyIds};
    final had = next.contains(pharmacyId);
    if (had) {
      next.remove(pharmacyId);
    } else {
      next.add(pharmacyId);
    }
    state = state.copyWith(favoritePharmacyIds: next);
    await _persistFavorites(next);

    final db = _ref.read(localDatabaseProvider);
    await db.updateOrgFavorite(pharmacyId, !had);

    try {
      final api = _ref.read(remoteApiServiceProvider);
      if (had) {
        await api.removeOrganizationFromFavorites(pharmacyId);
      } else {
        await api.addOrganizationToFavorites(pharmacyId);
      }
    } catch (_) {
      // Queue for retry when internet returns.
      try {
        await db.enqueueFavorite(
          entityType: 'pharmacy',
          entityId: pharmacyId,
          add: !had,
        );
      } catch (_) {}
      if (_ref.read(isOfflineProvider)) {
        pulseOfflineBanner(_ref);
      }
    }
    return !had;
  }

  Future<void> addToCart(
    Drug drug, {
    int quantity = 1,
    int? pharmacyId,
    String? pharmacyName,
  }) async {
    final items = [...state.cartItems];
    final index = items.indexWhere((item) => item.drugId == drug.id);
    if (index == -1) {
      items.add(
        CartItemSnapshot.fromDrug(
          drug,
          quantity: quantity,
          pharmacyId: pharmacyId,
          pharmacyName: pharmacyName,
          addedAt: DateTime.now().toIso8601String(),
        ),
      );
    } else {
      final current = items[index];
      items[index] = current.copyWith(quantity: current.quantity + quantity);
    }
    state = state.copyWith(cartItems: items);
    await _persistCart(items);
    if (_ref.read(isOfflineProvider)) {
      pulseOfflineBanner(_ref);
    }
  }

  Future<void> updateCartQuantity(int drugId, int quantity) async {
    final items = [...state.cartItems];
    final index = items.indexWhere((item) => item.drugId == drugId);
    if (index == -1) return;
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: quantity);
    }
    state = state.copyWith(cartItems: items);
    await _persistCart(items);
    if (_ref.read(isOfflineProvider)) {
      pulseOfflineBanner(_ref);
    }
  }

  Future<void> clearCart() async {
    final cartId = state.serverCartId;
    state = state.copyWith(cartItems: const [], clearServerCartId: true);
    await _persistCart(const []);
    if (_ref.read(isOfflineProvider)) {
      pulseOfflineBanner(_ref);
    }
    if (cartId != null) {
      try {
        final api = _ref.read(remoteApiServiceProvider);
        await api.clearServerCart(cartId);
      } catch (_) {
        // Best-effort: server cart deletion failures are non-blocking.
      }
    }
  }

  Future<void> clearExpiredCartItems() async {
    final active = _filterExpiredCart(state.cartItems);
    if (active.length == state.cartItems.length) return;
    state = state.copyWith(cartItems: active);
    await _persistCart(active);
  }

  static List<CartItemSnapshot> _filterExpiredCart(
    List<CartItemSnapshot> items,
  ) {
    final now = DateTime.now();
    final active = <CartItemSnapshot>[];
    for (final item in items) {
      final addedAt = item.addedAt;
      if (addedAt == null || addedAt.isEmpty) {
        active.add(item);
        continue;
      }
      final created = DateTime.tryParse(addedAt);
      if (created == null) {
        active.add(item);
        continue;
      }
      final expiresAt = created.add(const Duration(hours: 12));
      if (expiresAt.isAfter(now)) {
        active.add(item);
      }
    }
    return active;
  }
}

final appCollectionsProvider =
    StateNotifierProvider<AppCollectionsNotifier, AppCollectionsState>((ref) {
      return AppCollectionsNotifier(ref, ref.watch(sharedPreferencesProvider));
    });
