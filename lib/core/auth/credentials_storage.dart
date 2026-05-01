import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _accountsKey = 'stored_accounts';
const _currentLoginKey = 'stored_current_login';

final credentialsStorageProvider = Provider<CredentialsStorage>(
  (_) => CredentialsStorage(),
);

class CredentialsStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save(String login, String password) async {
    final accounts = await _loadAccounts();
    accounts[login] = password;
    await Future.wait([
      _storage.write(key: _accountsKey, value: jsonEncode(accounts)),
      _storage.write(key: _currentLoginKey, value: login),
    ]);
  }

  Future<({String login, String password})?> load() async {
    final currentLogin = await _storage.read(key: _currentLoginKey);
    if (currentLogin == null) return null;
    return loadForLogin(currentLogin);
  }

  Future<({String login, String password})?> loadForLogin(String login) async {
    final accounts = await _loadAccounts();
    final password = accounts[login];
    if (password == null) return null;
    return (login: login, password: password);
  }

  Future<void> setCurrentLogin(String login) async {
    await _storage.write(key: _currentLoginKey, value: login);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accountsKey),
      _storage.delete(key: _currentLoginKey),
    ]);
  }

  Future<Map<String, String>> _loadAccounts() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }
}
