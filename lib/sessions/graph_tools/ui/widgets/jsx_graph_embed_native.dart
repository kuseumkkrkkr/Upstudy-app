import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

Widget buildJsxGraphEmbedImpl(AiFlowGraphDocument document, {Key? key}) =>
    _JsxGraphEmbedNative(key: key, document: document);

class _JsxGraphEmbedNative extends StatefulWidget {
  const _JsxGraphEmbedNative({super.key, required this.document});

  final AiFlowGraphDocument document;

  @override
  State<_JsxGraphEmbedNative> createState() => _JsxGraphEmbedNativeState();
}

class _JsxGraphEmbedNativeState extends State<_JsxGraphEmbedNative> {
  InAppWebViewController? _controller;
  late String _payloadJson;

  @override
  void initState() {
    super.initState();
    _payloadJson = jsonEncode(widget.document.toJson());
  }

  @override
  void didUpdateWidget(covariant _JsxGraphEmbedNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPayloadJson = jsonEncode(widget.document.toJson());
    if (_payloadJson != nextPayloadJson) {
      _payloadJson = nextPayloadJson;
      _applyPayload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: buildAiFlowGraphHtml(widget.document),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
      },
    );
  }

  void _applyPayload() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final encodedPayloadLiteral = jsonEncode(_payloadJson);
    controller.evaluateJavascript(
      source: 'window.applyGraphPayload($encodedPayloadLiteral);',
    );
  }
}
