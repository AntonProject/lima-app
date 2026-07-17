import '../entities/cart_server_item.dart';

abstract interface class CartRepository {
  List<CartServerItem> readLocalItems();

  Future<void> persistLocalItems(List<CartServerItem> items);

  Future<List<CartServerItem>> getServerCart();

  Future<void> clearServerCart(int cartId);
}
