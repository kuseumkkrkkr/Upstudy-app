import 'package:web/web.dart' as web;
import 'dart:typed_data';
import 'dart:js_interop';

Future<String?> saveBytesForUser(Uint8List bytes, String filename) async {
  final blobParts = [bytes.toJS].toJS as JSArray<web.BlobPart>;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return null;
}
