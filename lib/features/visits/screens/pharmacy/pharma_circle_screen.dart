import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/features/knowledge/providers/knowledge_repository_provider.dart';
import 'package:lima/features/visits/domain/entities/completed_visit.dart';
import 'package:lima/features/visits/providers/pharma_circle_provider.dart';
import 'package:lima/features/visits/providers/visit_write_provider.dart';
import 'package:lima/features/visits/widgets/pharma_circle_finish_sheet.dart';
import 'package:lima/core/providers/connectivity_provider.dart';
import 'package:lima/core/providers/dashboard_counts_provider.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/widgets/app_widgets.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

import '../../../../core/models/models.dart';

part '../../widgets/pharma_circle_screen_widgets.dart';

class PharmaCircleScreen extends ConsumerStatefulWidget {
  final int pharmacyId;
  final String pharmacyName;

  const PharmaCircleScreen({
    super.key,
    required this.pharmacyId,
    this.pharmacyName = '',
  });

  @override
  ConsumerState<PharmaCircleScreen> createState() => _PharmaCircleScreenState();
}

class _PharmaCircleScreenState extends ConsumerState<PharmaCircleScreen> {
  bool _actionLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(pharmaCircleViewModelProvider.notifier).load(),
    );
  }

  void _setActionLocked(bool value) {
    setState(() => _actionLocked = value);
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);
}
