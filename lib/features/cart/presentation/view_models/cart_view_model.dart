import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartViewState {
  final String? checkingOutKey;

  const CartViewState({this.checkingOutKey});

  bool get isCheckingOut => checkingOutKey != null;

  CartViewState copyWith({String? checkingOutKey, bool clearKey = false}) {
    return CartViewState(
      checkingOutKey: clearKey ? null : (checkingOutKey ?? this.checkingOutKey),
    );
  }
}

class CartViewModel extends StateNotifier<CartViewState> {
  CartViewModel() : super(const CartViewState());

  bool beginCheckout(String key) {
    if (state.isCheckingOut) return false;
    state = state.copyWith(checkingOutKey: key);
    return true;
  }

  void clearCheckout() => state = state.copyWith(clearKey: true);
}
