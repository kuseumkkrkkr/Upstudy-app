import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';

Widget buildJsxGraphEmbedImpl(String html, {Key? key}) {
  final viewType = 'jsx-graph-${DateTime.now().microsecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    iframe.setAttribute('srcdoc', html);
    return iframe;
  });

  return HtmlElementView(key: key, viewType: viewType);
}
