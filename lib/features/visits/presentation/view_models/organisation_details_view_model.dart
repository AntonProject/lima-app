import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../domain/repositories/organisations_directory_repository.dart';

class OrganisationDetailsViewState {
  final Organisation? organisation;
  final bool isLoading;
  final String? error;

  const OrganisationDetailsViewState({
    this.organisation,
    this.isLoading = true,
    this.error,
  });

  OrganisationDetailsViewState copyWith({
    Organisation? organisation,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrganisationDetailsViewState(
      organisation: organisation ?? this.organisation,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrganisationDetailsViewModel
    extends StateNotifier<OrganisationDetailsViewState> {
  final OrganisationsDirectoryRepository _repository;
  final int organisationId;
  Future<void>? _activeLoad;

  OrganisationDetailsViewModel(this._repository, this.organisationId)
    : super(const OrganisationDetailsViewState()) {
    load();
  }

  Future<void> load() {
    final active = _activeLoad;
    if (active != null) return active;
    final future = _loadInternal();
    _activeLoad = future;
    future.whenComplete(() {
      if (identical(_activeLoad, future)) _activeLoad = null;
    });
    return future;
  }

  Future<void> _loadInternal() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final organisation = await _repository.getModelById(organisationId);
      if (!mounted) return;
      state = state.copyWith(organisation: organisation, isLoading: false);
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: '$error');
      }
    }
  }
}
