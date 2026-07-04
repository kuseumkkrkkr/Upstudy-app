import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists authentication data so that users stay signed in across launches.
class AuthStorage {
  AuthStorage._();

  static final AuthStorage instance = AuthStorage._();

  static const _tokenKey = 'teacher.auth.jwt';
  static const _usernameKey = 'teacher.auth.username';
  static const _roleKey = 'teacher.auth.role';

  static const _legacyTokenKey = 'auth.jwt';
  static const _legacyUsernameKey = 'auth.username';
  static const _legacyRoleKey = 'auth.role';

  Future<void> saveToken(String token, {String? username, String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedRole = _normalizeTeacherRole(role) ?? _roleFromToken(token);
    await prefs.setString(_tokenKey, token);
    if (username != null && username.trim().isNotEmpty) {
      await prefs.setString(_usernameKey, username.trim());
    }
    if (normalizedRole != null) {
      await prefs.setString(_roleKey, normalizedRole);
    } else {
      await prefs.remove(_roleKey);
    }
    await prefs.remove(_legacyRoleKey);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (_isTeacherToken(token)) {
      return token;
    }
    if (token != null) {
      await _clearTeacherKeys(prefs);
    }
    return _migrateLegacyTeacherToken(prefs);
  }

  Future<String?> readUsername() async {
    await readToken();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<String?> readRole() async {
    final token = await readToken();
    if (token == null) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final storedRole = _normalizeTeacherRole(prefs.getString(_roleKey));
    if (storedRole != null) {
      return storedRole;
    }
    final tokenRole = _roleFromToken(token);
    if (tokenRole != null) {
      await prefs.setString(_roleKey, tokenRole);
    }
    return tokenRole;
  }

  Future<bool> isTeacher() async {
    final role = await readRole();
    return role == 'teacher' || role == 'admin';
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearTeacherKeys(prefs);
    await prefs.remove(_legacyRoleKey);
  }

  Future<String?> _migrateLegacyTeacherToken(SharedPreferences prefs) async {
    final legacyToken = prefs.getString(_legacyTokenKey);
    if (!_isTeacherToken(legacyToken)) {
      await prefs.remove(_legacyRoleKey);
      return null;
    }

    final role = _roleFromToken(legacyToken);
    await prefs.setString(_tokenKey, legacyToken!);
    if (role != null) {
      await prefs.setString(_roleKey, role);
    }

    final legacyUsername = prefs.getString(_legacyUsernameKey);
    if (legacyUsername != null && legacyUsername.trim().isNotEmpty) {
      await prefs.setString(_usernameKey, legacyUsername.trim());
    }

    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_legacyUsernameKey);
    await prefs.remove(_legacyRoleKey);
    return legacyToken;
  }

  Future<void> _clearTeacherKeys(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
  }

  static bool _isTeacherToken(String? token) {
    return _roleFromToken(token) != null;
  }

  static String? _roleFromToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return _normalizeTeacherRole(decoded['role']?.toString());
    } catch (_) {
      return null;
    }
  }

  static String? _normalizeTeacherRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    if (normalized == 'teacher' || normalized == 'admin') {
      return normalized;
    }
    return null;
  }
}
