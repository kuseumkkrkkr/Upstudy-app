import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Widget buildJsxGraphEmbedImpl(String html, {Key? key}) {
  return InAppWebView(
    key: key,
    initialData: InAppWebViewInitialData(data: html),
    initialSettings: InAppWebViewSettings(
      javaScriptEnabled: true,
      transparentBackground: true,
    ),
  );
}
