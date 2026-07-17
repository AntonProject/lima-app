import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/view_models/cart_view_model.dart';

final cartViewModelProvider =
    StateNotifierProvider.autoDispose<CartViewModel, CartViewState>(
      (ref) => CartViewModel(),
    );
