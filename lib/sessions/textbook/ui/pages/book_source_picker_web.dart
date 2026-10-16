import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Uses the browser picker without uploading or evaluating the selected file.
Future<Uint8List?> pickBookSource() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json';
  final selected = Completer<web.File?>();
  input.onchange = ((web.Event _) {
    if (!selected.isCompleted) selected.complete(input.files?.item(0));
  }).toJS;
  input.oncancel = ((web.Event _) {
    if (!selected.isCompleted) selected.complete(null);
  }).toJS;
  input.click();
  try {
    final file = await selected.future;
    if (file == null) return null;
    if (file.size > 512 * 1024) throw const FormatException('size');
    return (await file.arrayBuffer().toDart).toDart.asUint8List();
  } finally {
    input.onchange = null;
    input.oncancel = null;
    input.remove();
  }
}
