import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

Future<String?> saveBytesForUser(Uint8List bytes, String filename) async {
  final dir = Directory.systemTemp;
  final safeName = filename.replaceAll('/', '_').replaceAll('\\', '_');
  final file = File(p.join(dir.path, safeName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
