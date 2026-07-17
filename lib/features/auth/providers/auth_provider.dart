import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_repository_provider.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool clearUser = false,
  }) => AuthState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    errorMessage: errorMessage,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(status: AuthStatus.loading);
    final user = await _repository.restoreSession();
    _setSession(user);
  }

  Future<bool> silentReauth() async {
    final user = await _repository.silentReauth();
    _setSession(user);
    return user != null;
  }

  Future<void> refreshProfile() async {
    final user = await _repository.refreshProfile();
    _setSession(user);
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.login(username, password);
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'errCannotOpenProfile',
        );
        return;
      }
      _setSession(user);
    } on AuthRepositoryFailure catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.messageKey,
      );
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'errInvalidCredentials',
      );
    }
  }

  Future<bool> loginOfflineWithCache() async {
    final user = await _repository.loginOfflineWithCache();
    _setSession(user);
    return user != null;
  }

  Future<void> logout() async {
    await _repository.logout();
    // Credentials are kept intentionally for silent re-auth on next launch.
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _setSession(UserModel? user) {
    state = user == null
        ? state.copyWith(status: AuthStatus.unauthenticated, clearUser: true)
        : state.copyWith(status: AuthStatus.authenticated, user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
