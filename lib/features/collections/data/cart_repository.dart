import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/remote_api_service.dart';

class CartRepository {
  final RemoteApiService _api;
  final SharedPreferences _prefs;

  CartRepository(this._api, this._prefs);

  static const _key = 'cart_items';

  List<String> readRawLocal() => _prefs.getStringList(_key) ?? const [];

  Future<void> persistRaw(List<String> encodedItems) =>
      _prefs.setStringList(_key, encodedItems);

  Future<List<Map<String, dynamic>>> getServerCart() => _api.getServerCart();

  Future<void> clearServerCart(int cartId) => _api.clearServerCart(cartId);
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(
    ref.watch(remoteApiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
