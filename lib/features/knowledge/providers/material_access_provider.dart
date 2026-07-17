import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/material_access_service_impl.dart';
import '../domain/services/material_access_service.dart';

final materialAccessServiceProvider = Provider<MaterialAccessService>((ref) {
  return MaterialAccessServiceImpl(ref.watch(apiClientProvider));
});
