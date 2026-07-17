import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/remote_api_service.dart';
import '../domain/repositories/cart_repository.dart';
import '../domain/entities/cart_server_item.dart';

class CartRepositoryImpl implements CartRepository {
  final RemoteApiService _api;
  final SharedPreferences _prefs;

  CartRepositoryImpl(this._api, this._prefs);

  static const _key = 'cart_items';

  @override
  List<CartServerItem> readLocalItems() {
    final rows = <CartServerItem>[];
    for (final raw in _prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          rows.add(CartServerItem.fromMap(Map<String, dynamic>.from(decoded)));
        } else if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            rows.add(CartServerItem.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      } catch (_) {
        // Ignore malformed legacy values and keep the valid cart entries.
      }
    }
    return rows;
  }

  @override
  Future<void> persistLocalItems(List<CartServerItem> items) {
    final encoded = items.map((item) => jsonEncode(item.toMap())).toList();
    return _prefs.setStringList(_key, encoded);
  }

  @override
  Future<List<CartServerItem>> getServerCart() async {
    final rows = await _api.getServerCart();
    return rows.map(CartServerItem.fromMap).toList(growable: false);
  }

  @override
  Future<void> clearServerCart(int cartId) => _api.clearServerCart(cartId);
}

final cartRepositoryProvider = Provider<CartRepositoryImpl>((ref) {
  return CartRepositoryImpl(
    ref.watch(remoteApiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
