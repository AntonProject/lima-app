import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/collections/domain/repositories/cart_repository.dart';
import 'package:lima/features/collections/domain/repositories/favorites_repository.dart';
import 'package:lima/features/collections/domain/entities/cart_server_item.dart';
import 'package:lima/features/collections/domain/use_cases/toggle_favorite_pharmacy.dart';
import 'package:lima/features/collections/providers/collections_repository_providers.dart';
import 'package:lima/core/utils/swallowed.dart';

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
  final int? cartId;
  final int? prepaymentPercent;
  final int? buyerType;

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
    this.cartId,
    this.prepaymentPercent,
    this.buyerType,
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
      cartId: cartId,
      prepaymentPercent: prepaymentPercent,
      buyerType: buyerType,
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
      if (cartId != null) 'cart_id': cartId,
      if (prepaymentPercent != null) 'prepayment_percent': prepaymentPercent,
      if (buyerType != null) 'buyer_type': buyerType,
      if (currentStockId != null) 'current_stock_id': currentStockId,
      if (bindingDrugId != null) 'binding_drug_id': bindingDrugId,
    };
  }

  factory CartItemSnapshot.fromJson(Map<String, dynamic> json) {
    final isWholesaler = _toBool(json['is_wholesaler']);
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
      cartId: json['cart_id'] as int?,
      prepaymentPercent:
          _toInt(json['prepayment_percent']) ?? _toInt(json['prepayment']),
      buyerType:
          _toInt(json['buyer_type']) ??
          (isWholesaler == null ? null : (isWholesaler ? 1 : 0)),
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
    int? cartId,
    int? prepaymentPercent,
    int? buyerType,
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
      cartId: cartId,
      prepaymentPercent: prepaymentPercent,
      buyerType: buyerType,
      currentStockId: drug.currentStockId,
      bindingDrugId: drug.bindingDrugId,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
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
  final FavoritesRepository _favorites;
  final CartRepository _cart;
  late final ToggleFavoritePharmacy _toggleFavorite = ToggleFavoritePharmacy(
    _favorites,
  );

  AppCollectionsNotifier(this._ref, this._favorites, this._cart)
    : super(const AppCollectionsState()) {
    _load();
  }

  Future<void> _load() async {
    final favoritePharmacyIds = _favorites.readLocal();

    final storedCartItems = _cart.readLocalItems();
    final cartItems = storedCartItems
        .map((item) => CartItemSnapshot.fromJson(item.toMap()))
        .toList(growable: false);

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
      final remoteIds = await _favorites.getRemoteFavoriteOrgIds();
      await _favorites.clearOrgFavoritesLocal();
      for (final id in remoteIds) {
        await _favorites.setOrgFavoriteLocal(id, true);
      }
      state = state.copyWith(favoritePharmacyIds: remoteIds);
      await _persistFavorites(remoteIds);
    } catch (_) {
      // Keep local favorites when API is unavailable.
    }

    // Load server-side cart — overwrites local cache if server returns items.
    try {
      final serverItems = await _cart.getServerCart();
      if (serverItems.isNotEmpty) {
        final cartItems = serverItems
            .map((e) => CartItemSnapshot.fromJson(e.toMap()))
            .toList();
        // Extract the cart ID from the first item so we can delete it later.
        final cartId = serverItems.first.cartId;
        state = state.copyWith(cartItems: cartItems, serverCartId: cartId);
        await _persistCart(cartItems);
      }
    } catch (_) {
      // Keep local cart when API is unavailable (offline mode).
    }
  }

  Future<void> _persistFavorites(Set<int> ids) => _favorites.persist(ids);

  Future<void> _persistCart(List<CartItemSnapshot> items) =>
      _cart.persistLocalItems(
        items
            .map((item) => CartServerItem.fromMap(item.toJson()))
            .toList(growable: false),
      );

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

    try {
      final result = await _toggleFavorite(
        pharmacyId: pharmacyId,
        currentlyFavorite: had,
        isOffline: _ref.read(isOfflineProvider),
      );
      if (result.isFavorite != !had) {
        state = state.copyWith(
          favoritePharmacyIds: {...state.favoritePharmacyIds}
            ..remove(pharmacyId),
        );
        if (had) {
          state = state.copyWith(
            favoritePharmacyIds: {...state.favoritePharmacyIds, pharmacyId},
          );
        }
        await _persistFavorites(state.favoritePharmacyIds);
      }
      if (result.queued) {
        pulseOfflineBanner(_ref);
      }
    } catch (error, stackTrace) {
      debugPrint('Favorite mutation failed: $error\n$stackTrace');
      final restored = {...state.favoritePharmacyIds};
      if (had) {
        restored.add(pharmacyId);
      } else {
        restored.remove(pharmacyId);
      }
      state = state.copyWith(favoritePharmacyIds: restored);
      await _persistFavorites(restored);
    }
    return !had;
  }

  Future<void> addToCart(
    Drug drug, {
    int quantity = 1,
    int? pharmacyId,
    String? pharmacyName,
    int? prepaymentPercent,
    int? buyerType,
  }) async {
    final items = [...state.cartItems];
    final index = items.indexWhere(
      (item) =>
          item.drugId == drug.id &&
          item.pharmacyId == pharmacyId &&
          (item.prepaymentPercent ?? 100) == (prepaymentPercent ?? 100) &&
          (item.buyerType ?? 0) == (buyerType ?? 0),
    );
    if (index == -1) {
      items.add(
        CartItemSnapshot.fromDrug(
          drug,
          quantity: quantity,
          pharmacyId: pharmacyId,
          pharmacyName: pharmacyName,
          addedAt: DateTime.now().toIso8601String(),
          prepaymentPercent: prepaymentPercent,
          buyerType: buyerType,
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

  Future<void> updateCartQuantity(
    int drugId,
    int quantity, {
    int? pharmacyId,
    int? cartId,
    int? prepaymentPercent,
    int? buyerType,
  }) async {
    final items = [...state.cartItems];
    final index = items.indexWhere((item) {
      if (item.drugId != drugId) return false;
      if (cartId != null && item.cartId != cartId) return false;
      if (pharmacyId != null && item.pharmacyId != pharmacyId) return false;
      if (prepaymentPercent != null) {
        if ((item.prepaymentPercent ?? 100) != prepaymentPercent) return false;
      }
      if (buyerType != null && (item.buyerType ?? 0) != buyerType) {
        return false;
      }
      return true;
    });
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

  Future<void> clearCartGroup({
    int? pharmacyId,
    String? pharmacyName,
    int? cartId,
    int? prepaymentPercent,
    int? buyerType,
  }) async {
    final items = [...state.cartItems];
    final removedCartIds = <int>{};
    items.removeWhere((item) {
      var matches = cartId != null
          ? item.cartId == cartId
          : pharmacyId != null
          ? item.pharmacyId == pharmacyId
          : item.pharmacyName == pharmacyName;
      if (matches && prepaymentPercent != null) {
        matches = (item.prepaymentPercent ?? 100) == prepaymentPercent;
      }
      if (matches && buyerType != null) {
        matches = (item.buyerType ?? 0) == buyerType;
      }
      if (matches && item.cartId != null) {
        removedCartIds.add(item.cartId!);
      }
      return matches;
    });
    state = state.copyWith(cartItems: items);
    await _persistCart(items);
    if (_ref.read(isOfflineProvider)) {
      pulseOfflineBanner(_ref);
    }
    for (final id in removedCartIds) {
      try {
        await _cart.clearServerCart(id);
      } catch (error) {
        logSwallowed(error, 'AppCollectionsNotifier.removeExpiredCart');
      }
    }
  }

  Future<void> clearCart() async {
    final cartIds = {
      if (state.serverCartId != null) state.serverCartId!,
      ...state.cartItems.map((e) => e.cartId).whereType<int>(),
    };
    state = state.copyWith(cartItems: const [], clearServerCartId: true);
    await _persistCart(const []);
    if (_ref.read(isOfflineProvider)) {
      pulseOfflineBanner(_ref);
    }
    for (final cartId in cartIds) {
      try {
        await _cart.clearServerCart(cartId);
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
      return AppCollectionsNotifier(
        ref,
        ref.watch(favoritesRepositoryProvider),
        ref.watch(cartRepositoryProvider),
      );
    });
