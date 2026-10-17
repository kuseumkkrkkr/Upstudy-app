import 'local_db.dart';
import 'package:s11/shared/services/api/api_client.dart';

class LocalDbUnsupported implements LocalDb {
  @override
  Future<String?> getString(
    String key, {
    ApiSessionScope? scope,
    bool forceRefresh = false,
  }) async {
    scope ??= await ApiClient.instance.requireSessionScope();
    ApiClient.instance.assertSessionScope(scope);
    throw UnsupportedError('LocalDb is not supported on this platform.');
  }

  @override
  Future<void> setString(
    String key,
    String value, {
    ApiSessionScope? scope,
  }) async {
    scope ??= await ApiClient.instance.requireSessionScope();
    ApiClient.instance.assertSessionScope(scope);
    throw UnsupportedError('LocalDb is not supported on this platform.');
  }

  @override
  Future<void> delete(String key, {ApiSessionScope? scope}) async {
    scope ??= await ApiClient.instance.requireSessionScope();
    ApiClient.instance.assertSessionScope(scope);
    throw UnsupportedError('LocalDb is not supported on this platform.');
  }
}

LocalDb createLocalDbImpl() => LocalDbUnsupported();
