import 'package:flutter/foundation.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'local_db.dart';

class LocalDbWeb implements LocalDb {
  LocalDbWeb();

  final ApiClient _api = ApiClient.instance;

  @override
  Future<String?> getString(String key) async {
    try {
      return await _api.getUserStorage(key);
    } on ApiException catch (error) {
      // Missing keys are expected on first load; treat as cache miss.
      if (error.statusCode == 404) {
        return null;
      }
      if (kDebugMode) {
        debugPrint('LocalDbWeb.getString failed: $error');
      }
      return null;
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
