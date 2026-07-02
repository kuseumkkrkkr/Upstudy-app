import 'local_db.dart';

class LocalDbUnsupported implements LocalDb {
  @override
  Future<String?> getString(String key) {
    throw UnsupportedError('LocalDb is not supported on this platform.');
  }

  @override
  Future<void> setString(String key, String value) {
    throw UnsupportedError('LocalDb is not supported on this platform.');
  }

  @override
  Future<void> delete(String key) {
    throw UnsupportedError('LocalDb is not supported on this platform.');
  }
}

LocalDb createLocalDbImpl() => LocalDbUnsupported();
