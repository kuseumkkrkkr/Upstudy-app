import 'local_db_stub.dart'
    if (dart.library.html) 'local_db_web.dart'
    if (dart.library.io) 'local_db_io.dart';

abstract class LocalDb {
  static final LocalDb instance = createLocalDb();

  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> delete(String key);
}

LocalDb createLocalDb() => createLocalDbImpl();
