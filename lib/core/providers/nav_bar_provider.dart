import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Управляет видимостью глобального навбара.
/// Экраны, на которых навбар не нужен, выставляют [hideNavBarProvider] = true
/// через initState и сбрасывают в dispose.
final hideNavBarProvider = StateProvider<bool>((ref) => false);
