import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'local_db.dart';

class LocalDbWeb implements LocalDb {
  LocalDbWeb();

  final ApiClient _api = ApiClient.instance;

  @override
  Future<String?> getString(String key) async {
    try {
      return await _api.getUserStorage(key);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('LocalDbWeb.getString failed: $error');
      }
      return null;
    }
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
  }
}

LocalDb createLocalDbImpl() => LocalDbWeb();
