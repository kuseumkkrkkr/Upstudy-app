import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

Widget buildJsxGraphEmbedImpl(AiFlowGraphDocument document, {Key? key}) =>
    _JsxGraphEmbedWeb(key: key, document: document);

class _JsxGraphEmbedWeb extends StatefulWidget {
  const _JsxGraphEmbedWeb({super.key, required this.document});

  final AiFlowGraphDocument document;

  @override
  State<_JsxGraphEmbedWeb> createState() => _JsxGraphEmbedWebState();
}

class _JsxGraphEmbedWebState extends State<_JsxGraphEmbedWeb> {
  static int _viewTypeSeed = 0;

  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late String _payloadJson;

  @override
  void initState() {
    super.initState();
    _payloadJson = jsonEncode(widget.document.toJson());
    _viewType = 'jsx-graph-${_viewTypeSeed++}';
    _iframe = web.HTMLIFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block';
    _iframe.setAttribute('srcdoc', buildAiFlowGraphHtml(widget.document));

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });
  }

  @override
  void didUpdateWidget(covariant _JsxGraphEmbedWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPayloadJson = jsonEncode(widget.document.toJson());
    if (_payloadJson != nextPayloadJson) {
      _payloadJson = nextPayloadJson;
      _iframe.contentWindow?.postMessage(_payloadJson.toJS, '*'.toJS);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
