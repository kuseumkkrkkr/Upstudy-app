import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

/// 필요한 변수: 플랫폼 구현체 존재 여부와 그래프 문서.
/// 작동 원리: 테스트/지원 불가 환경에서는 웹뷰 대신 안내 박스로 대체해 앱 크래시를 막는다.
Widget buildJsxGraphEmbedImpl(
  AiFlowGraphDocument document, {
  Key? key,
  bool showParameterControls = true,
  bool directManipulationMode = false,
}) {
  if (InAppWebViewPlatform.instance == null) {
    return Center(key: key, child: const Text('그래프 뷰어를 준비 중입니다.'));
  }
  return _JsxGraphEmbedNative(
    key: key,
    document: document,
    showParameterControls: showParameterControls,
    directManipulationMode: directManipulationMode,
  );
}

class _JsxGraphEmbedNative extends StatefulWidget {
  const _JsxGraphEmbedNative({
    super.key,
    required this.document,
    required this.showParameterControls,
    required this.directManipulationMode,
  });

  final AiFlowGraphDocument document;
  final bool showParameterControls;
  final bool directManipulationMode;

  @override
  State<_JsxGraphEmbedNative> createState() => _JsxGraphEmbedNativeState();
}

class _JsxGraphEmbedNativeState extends State<_JsxGraphEmbedNative> {
  InAppWebViewController? _controller;
  late String _payloadJson;
  bool _webLoaded = false;

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
        data: buildAiFlowGraphHtml(
          widget.document,
          showParameterControls: widget.showParameterControls,
          directManipulationMode: widget.directManipulationMode,
        ),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
      },
      onLoadStop: (_, __) {
        _webLoaded = true;
        _applyPayload();
      },
    );
  }

  void _applyPayload() {
    final controller = _controller;
    if (controller == null || !_webLoaded) {
      return;
    }
    final encodedPayloadLiteral = jsonEncode(_payloadJson);
    controller.evaluateJavascript(
      source: 'window.applyGraphPayload($encodedPayloadLiteral);',
    );
  }
}
