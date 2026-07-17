import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/models/models.dart';

import '../../domain/repositories/doctors_directory_repository.dart';

class LpuDetailsViewState {
  final List<Doctor> doctors;
  final Map<int, int> visitCounts;
  final Set<int> visitedDoctorIds;
  final bool isLoading;
  final String? error;

  const LpuDetailsViewState({
    this.doctors = const [],
    this.visitCounts = const {},
    this.visitedDoctorIds = const {},
    this.isLoading = false,
    this.error,
  });

  LpuDetailsViewState copyWith({
    List<Doctor>? doctors,
    Map<int, int>? visitCounts,
    Set<int>? visitedDoctorIds,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LpuDetailsViewState(
      doctors: doctors ?? this.doctors,
      visitCounts: visitCounts ?? this.visitCounts,
      visitedDoctorIds: visitedDoctorIds ?? this.visitedDoctorIds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LpuDetailsViewModel extends StateNotifier<LpuDetailsViewState> {
  final DoctorsDirectoryRepository _repository;
  final int organizationId;
  bool _remoteLoadAttempted = false;
  Future<void>? _activeLoad;
  int _loadGeneration = 0;

  LpuDetailsViewModel(this._repository, this.organizationId)
    : super(const LpuDetailsViewState());

  Future<void> load({bool fetchRemote = true}) async {
    final activeLoad = _activeLoad;
    if (activeLoad != null) return activeLoad;
    final future = _loadInternal(fetchRemote: fetchRemote);
    _activeLoad = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_activeLoad, future)) _activeLoad = null;
      }),
    );
    return future;
  }

  Future<void> _loadInternal({required bool fetchRemote}) async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var doctors = await _repository.getDoctorModels(
        orgId: organizationId,
        includeGlobalFallback: false,
      );

      if (fetchRemote && !_remoteLoadAttempted) {
        _remoteLoadAttempted = true;
        try {
          final remoteDoctors = await _repository.getByOrganizationRemoteModels(
            organizationId,
          );
          if (remoteDoctors.isNotEmpty) {
            await _repository.upsertDoctorModels(remoteDoctors);
            await _repository.upsertOrganisationLinksFor(
              organizationId: organizationId,
              doctorIds: remoteDoctors.map((doctor) => doctor.id).toList(),
            );
            doctors = await _repository.getDoctorModels(
              orgId: organizationId,
              includeGlobalFallback: false,
            );
          }
        } catch (_) {
          // Local data remains the source of truth when the remote repair fails.
        }
      }

      final visitCounts = await _repository.getVisitCountsByDoctorIds(
        doctors.map((doctor) => doctor.id).toList(),
      );
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        doctors: List.unmodifiable(doctors),
        visitCounts: Map.unmodifiable(visitCounts),
        visitedDoctorIds: Set.unmodifiable(
          visitCounts.entries
              .where((entry) => entry.value > 0)
              .map((entry) => entry.key),
        ),
        isLoading: false,
      );
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        state = state.copyWith(isLoading: false, error: '$error');
      }
    }
  }

  Future<void> ensureDoctorLoaded(int doctorId) async {
    if (state.doctors.any((doctor) => doctor.id == doctorId)) return;
    final doctor = await _repository.getDoctorModel(doctorId);
    if (!mounted || doctor == null) return;
    state = state.copyWith(
      doctors: List.unmodifiable([doctor, ...state.doctors]),
    );
  }

  void setDoctorFavorite(int doctorId, bool isFavorite) {
    final updated = state.doctors
        .map(
          (doctor) => doctor.id == doctorId
              ? _withFavorite(doctor, isFavorite)
              : doctor,
        )
        .toList(growable: false);
    state = state.copyWith(doctors: List.unmodifiable(updated));
  }

  static Doctor _withFavorite(Doctor doctor, bool isFavorite) => Doctor(
    id: doctor.id,
    fullName: doctor.fullName,
    specialty: doctor.specialty,
    specializationId: doctor.specializationId,
    organisationId: doctor.organisationId,
    isFavorite: isFavorite,
    category: doctor.category,
    lastVisitLabel: doctor.lastVisitLabel,
    phone: doctor.phone,
    hobby: doctor.hobby,
    interests: doctor.interests,
    birthday: doctor.birthday,
    updatedAt: doctor.updatedAt,
    rawJson: doctor.rawJson,
  );
}
