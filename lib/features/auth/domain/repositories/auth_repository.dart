import '../../../../core/models/models.dart';
import '../../../../core/failures/result.dart';

/// Application-facing authentication contract.
///
/// The notifier owns UI state; this contract owns token, profile and cached
/// session orchestration so presentation does not depend on API/SQLite types.
abstract interface class AuthRepository {
  Future<UserModel?> restoreSession();

  Future<UserModel?> silentReauth();

  Future<UserModel?> login(String username, String password);

  Future<UserModel?> loginOfflineWithCache();

  Future<UserModel?> refreshProfile();

  Future<void> logout();
}

class AuthRepositoryFailure extends AppFailure {
  final String messageKey;

  const AuthRepositoryFailure(this.messageKey) : super(messageKey);
}
