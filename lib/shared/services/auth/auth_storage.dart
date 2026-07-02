import 'package:shared_preferences/shared_preferences.dart';

/// Persists authentication data so that users stay signed in across launches.
class AuthStorage {
  AuthStorage._();

  static final AuthStorage instance = AuthStorage._();

  static const _tokenKey = 'auth.jwt';
  static const _usernameKey = 'auth.username';

  Future<void> saveToken(String token, {String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (username != null && username.trim().isNotEmpty) {
      await prefs.setString(_usernameKey, username.trim());
    }
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username.trim());
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> readUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
  }
}
