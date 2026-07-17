import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/auth/domain/repositories/auth_repository.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';

void main() {
  test(
    'clears the previous profile when session restoration returns null',
    () async {
      final repository = _FakeAuthRepository(restoreUser: _user(1, 'First'));
      final notifier = AuthNotifier(repository);
      addTearDown(notifier.dispose);

      await _flushAsyncWork();
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user?.id, 1);

      repository.refreshUser = null;
      await notifier.refreshProfile();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
    },
  );

  test('keeps cached user scoped to the repository result on login', () async {
    final repository = _FakeAuthRepository(loginUser: _user(2, 'Second'));
    final notifier = AuthNotifier(repository);
    addTearDown(notifier.dispose);

    await _flushAsyncWork();
    await notifier.login('second', 'password');

    expect(notifier.state.status, AuthStatus.authenticated);
    expect(notifier.state.user?.id, 2);
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

UserModel _user(int id, String name) {
  return UserModel(id: id, fullName: name, role: 'mp', regionId: 1);
}

class _FakeAuthRepository implements AuthRepository {
  final UserModel? restoreUser;
  final UserModel? loginUser;
  UserModel? refreshUser;

  _FakeAuthRepository({this.restoreUser, this.loginUser})
    : refreshUser = restoreUser;

  @override
  Future<UserModel?> restoreSession() async => restoreUser;

  @override
  Future<UserModel?> silentReauth() async => restoreUser;

  @override
  Future<UserModel?> login(String username, String password) async => loginUser;

  @override
  Future<UserModel?> loginOfflineWithCache() async => restoreUser;

  @override
  Future<UserModel?> refreshProfile() async => refreshUser;

  @override
  Future<void> logout() async {}
}
