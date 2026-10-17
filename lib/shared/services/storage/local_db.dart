import 'package:s11/shared/services/api/api_client.dart';
import 'local_db_stub.dart'
    if (dart.library.html) 'local_db_web.dart'
    if (dart.library.io) 'local_db_io.dart';

abstract class LocalDb {
  static final LocalDb instance = createLocalDb();

  Future<String?> getString(
    String key, {
    ApiSessionScope? scope,
    bool forceRefresh = false,
  });
  Future<void> setString(String key, String value, {ApiSessionScope? scope});
  Future<void> delete(String key, {ApiSessionScope? scope});
}

LocalDb createLocalDb() => createLocalDbImpl();
