abstract interface class SplashBootstrapRepository {
  Future<void> initializeDatabase();

  Future<bool> hasRealInternet();

  bool get hasApiToken;

  Future<({String login, String password})?> loadCredentials();

  Future<bool> hasOfflineSessionFor(String login);

  Future<bool> hasLocalOrganizations();
}
