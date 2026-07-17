import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cart_repository.dart' as data_cart;
import '../data/favorites_repository.dart' as data_favorites;
import '../domain/repositories/cart_repository.dart';
import '../domain/repositories/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return ref.watch(data_favorites.favoritesRepositoryProvider);
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return ref.watch(data_cart.cartRepositoryProvider);
});
