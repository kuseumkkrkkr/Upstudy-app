import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'local_db.dart';

class LocalDbWeb implements LocalDb {
  LocalDbWeb();

  final ApiClient _api = ApiClient.instance;
  static const String _debugPrefix = 'web_debug_db::';

  @override
  Future<String?> getString(String key) async {
    try {
      final remote = await _api.getUserStorage(key);
      if (remote != null) return remote;
    } on ApiException catch (error) {
      // Missing keys are expected on first load; treat as cache miss.
      if (kDebugMode && error.statusCode != 404) {
        debugPrint('LocalDbWeb.getString failed: $error');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('LocalDbWeb.getString failed: $error');
      }
    }
    return _readFallback(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    try {
      await _api.setUserStorage(key, value);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('LocalDbWeb.setString failed: $error');
      }
    }
    await _writeFallback(key, value);
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _api.deleteUserStorage(key);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('LocalDbWeb.delete failed: $error');
      }
    }
    await _deleteFallback(key);
  }

  Future<String?> _readFallback(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_debugPrefix$key');
  }

  Future<void> _writeFallback(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_debugPrefix$key', value);
  }

  Future<void> _deleteFallback(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_debugPrefix$key');
  }
}

LocalDb createLocalDbImpl() => LocalDbWeb();
