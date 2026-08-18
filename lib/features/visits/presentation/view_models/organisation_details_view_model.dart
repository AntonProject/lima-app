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

  OrganisationDetailsViewModel(
    this._repository,
    this.organisationId, {
    required bool fetchRemote,
  }) : super(const OrganisationDetailsViewState()) {
    load(fetchRemote: fetchRemote);
  }

  Future<void> load({bool fetchRemote = false}) {
    final active = _activeLoad;
    if (active != null) return active;
    final future = _loadInternal(fetchRemote: fetchRemote);
    _activeLoad = future;
    future.whenComplete(() {
      if (identical(_activeLoad, future)) _activeLoad = null;
    });
    return future;
  }

  Future<void> _loadInternal({required bool fetchRemote}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final localOrganisation = await _repository.getModelById(organisationId);
      if (!mounted) return;
      state = state.copyWith(
        organisation: localOrganisation,
        isLoading: !fetchRemote && localOrganisation == null,
      );

      if (!fetchRemote) {
        if (mounted) {
          state = state.copyWith(isLoading: false);
        }
        return;
      }

      try {
        final remoteOrganisation = await _repository.getRemoteModelById(
          organisationId,
        );
        if (!mounted) return;
        state = state.copyWith(
          organisation: remoteOrganisation ?? localOrganisation,
          isLoading: false,
        );
      } catch (_) {
        // The local card remains usable when the detail refresh fails. Only
        // surface an error if there was no cached organisation to display.
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: localOrganisation == null ? 'Не удалось загрузить ЛПУ' : null,
          clearError: localOrganisation != null,
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: '$error');
      }
    }
  }
}
