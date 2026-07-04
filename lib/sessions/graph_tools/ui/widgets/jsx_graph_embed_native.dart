import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Widget buildJsxGraphEmbedImpl(String html, {Key? key}) =>
    _JsxGraphEmbedNative(key: key, html: html);

class _JsxGraphEmbedNative extends StatefulWidget {
  const _JsxGraphEmbedNative({super.key, required this.html});

  final String html;

  @override
  State<_JsxGraphEmbedNative> createState() => _JsxGraphEmbedNativeState();
}

class _JsxGraphEmbedNativeState extends State<_JsxGraphEmbedNative> {
  InAppWebViewController? _controller;

  @override
  void didUpdateWidget(covariant _JsxGraphEmbedNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html && _controller != null) {
      _controller!.loadData(data: widget.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(data: widget.html),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
      },
    );
  }
}
