import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';

Widget buildJsxGraphEmbedImpl(String html, {Key? key}) =>
    _JsxGraphEmbedWeb(key: key, html: html);

class _JsxGraphEmbedWeb extends StatefulWidget {
  const _JsxGraphEmbedWeb({super.key, required this.html});

  final String html;

  @override
  State<_JsxGraphEmbedWeb> createState() => _JsxGraphEmbedWebState();
}

class _JsxGraphEmbedWebState extends State<_JsxGraphEmbedWeb> {
  static int _viewTypeSeed = 0;

  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _viewType = 'jsx-graph-${_viewTypeSeed++}';
    _iframe = web.HTMLIFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block';
    _iframe.setAttribute('srcdoc', widget.html);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });
  }

  @override
  void didUpdateWidget(covariant _JsxGraphEmbedWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _iframe.setAttribute('srcdoc', widget.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
