import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'local_db.dart';

class LocalDbWeb implements LocalDb {
  LocalDbWeb();

  final ApiClient _api = ApiClient.instance;
  static const String _debugPrefix = 'web_debug_db::';

  @override
  Future<String?> getString(
    String key, {
    ApiSessionScope? scope,
    bool forceRefresh = false,
  }) async {
    scope ??= await _api.requireSessionScope();
    _api.assertSessionScope(scope);
    Object? unavailable;
    StackTrace? unavailableStack;
    try {
      final remote = await _api.getUserStorage(
        key,
        scope: scope,
        forceRefresh: forceRefresh,
      );
      _api.assertSessionScope(scope);
      if (remote == null) {
        await _deleteFallback(key, scope);
      } else {
        await _writeFallback(key, remote, scope);
      }
      _api.assertSessionScope(scope);
      return remote;
    } on ApiException catch (error, stack) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      _api.assertSessionScope(scope);
      if (error.statusCode == 404) {
        await _deleteFallback(key, scope);
        return null;
      }
      if (error.statusCode < 500) rethrow;
      unavailable = error;
      unavailableStack = stack;
    } on http.ClientException catch (error, stack) {
      _api.assertSessionScope(scope);
      unavailable = error;
      unavailableStack = stack;
    } on TimeoutException catch (error, stack) {
      _api.assertSessionScope(scope);
      unavailable = error;
      unavailableStack = stack;
    }
    final cached = await _readFallback(key, scope);
    if (cached != null) return cached;
    Error.throwWithStackTrace(unavailable!, unavailableStack!);
  }

  @override
  Future<void> setString(
    String key,
    String value, {
    ApiSessionScope? scope,
  }) async {
    scope ??= await _api.requireSessionScope();
    _api.assertSessionScope(scope);
    await _api.setUserStorage(key, value, scope: scope);
    _api.assertSessionScope(scope);
    await _writeFallback(key, value, scope);
  }

  @override
  Future<void> delete(String key, {ApiSessionScope? scope}) async {
    scope ??= await _api.requireSessionScope();
    _api.assertSessionScope(scope);
    await _api.deleteUserStorage(key, scope: scope);
    _api.assertSessionScope(scope);
    await _deleteFallback(key, scope);
  }

  Future<String?> _readFallback(String key, ApiSessionScope scope) async {
    final prefs = await SharedPreferences.getInstance();
    _api.assertSessionScope(scope);
    return prefs.getString('$_debugPrefix${scope.namespace}::$key');
  }

  Future<void> _writeFallback(
    String key,
    String value,
    ApiSessionScope scope,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    _api.assertSessionScope(scope);
    await prefs.setString('$_debugPrefix${scope.namespace}::$key', value);
    _api.assertSessionScope(scope);
  }

  Future<void> _deleteFallback(String key, ApiSessionScope scope) async {
    final prefs = await SharedPreferences.getInstance();
    _api.assertSessionScope(scope);
    await prefs.remove('$_debugPrefix${scope.namespace}::$key');
    _api.assertSessionScope(scope);
  }
}

LocalDb createLocalDbImpl() => LocalDbWeb();
