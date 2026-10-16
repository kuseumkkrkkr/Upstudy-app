import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';
import 'package:s11/sessions/graph_tools/shared/graph_parameter_observation.dart';

/// 필요한 변수: 플랫폼 구현체 존재 여부와 그래프 문서.
/// 작동 원리: 테스트/지원 불가 환경에서는 웹뷰 대신 안내 박스로 대체해 앱 크래시를 막는다.
Widget buildJsxGraphEmbedImpl(
  AiFlowGraphDocument document, {
  Key? key,
  bool showParameterControls = true,
  bool directManipulationMode = false,
  bool interactive = true,
  String? command,
  int commandRevision = 0,
  ValueChanged<AiFlowGraphViewport>? onViewportChanged,
  ValueChanged<Map<String, double>>? onParametersChanged,
}) {
  if (InAppWebViewPlatform.instance == null) {
    return Center(key: key, child: const Text('그래프 뷰어를 준비 중입니다.'));
  }
  return _JsxGraphEmbedNative(
    key: key,
    document: document,
    showParameterControls: showParameterControls,
    directManipulationMode: directManipulationMode,
    interactive: interactive,
    command: command,
    commandRevision: commandRevision,
    onViewportChanged: onViewportChanged,
    onParametersChanged: onParametersChanged,
  );
}

class _JsxGraphEmbedNative extends StatefulWidget {
  const _JsxGraphEmbedNative({
    super.key,
    required this.document,
    required this.showParameterControls,
    required this.directManipulationMode,
    this.interactive = true,
    this.command,
    this.commandRevision = 0,
    this.onViewportChanged,
    this.onParametersChanged,
  });

  final AiFlowGraphDocument document;
  final bool showParameterControls;
  final bool directManipulationMode;
  final bool interactive;
  final String? command;
  final int commandRevision;
  final ValueChanged<AiFlowGraphViewport>? onViewportChanged;
  final ValueChanged<Map<String, double>>? onParametersChanged;

  @override
  State<_JsxGraphEmbedNative> createState() => _JsxGraphEmbedNativeState();
}

class _JsxGraphEmbedNativeState extends State<_JsxGraphEmbedNative> {
  InAppWebViewController? _controller;
  late String _payloadJson;
  int _observationRevision = 0;
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
    final command = widget.commandRevision != oldWidget.commandRevision ? widget.command : null;
    if (_payloadJson != nextPayloadJson) {
      _payloadJson = nextPayloadJson;
      _observationRevision++;
      _applyPayload().then((_) {
        if (mounted && command != null) _controller?.evaluateJavascript(source: 'window.applyGraphCommand(${jsonEncode(command)});');
      });
    } else if (command != null) {
      _controller?.evaluateJavascript(source: 'window.applyGraphCommand(${jsonEncode(command)});');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(ignoring: !widget.interactive, child: InAppWebView(
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
        controller.addJavaScriptHandler(handlerName: 'aiflowParameters', callback: (arguments) {
          if (!mounted || !widget.interactive || arguments.isEmpty || arguments.first is! Map) return;
          final data = arguments.first as Map;
          final values = readGraphParameterEvent(widget.document, data, _observationRevision);
          if (values != null) widget.onParametersChanged?.call(values);
        });
        controller.addJavaScriptHandler(handlerName: 'aiflowViewport', callback: (arguments) {
          if (arguments.isEmpty || arguments.first is! Map) return;
          final data = arguments.first as Map;
          final values = ['left', 'right', 'top', 'bottom'].map((key) => data[key]).toList();
          if (values.any((value) => value is! num || !value.isFinite)) return;
          if (values[0] >= values[1] || values[3] >= values[2]) return;
          widget.onViewportChanged?.call(AiFlowGraphViewport(left: (values[0] as num).toDouble(), right: (values[1] as num).toDouble(), top: (values[2] as num).toDouble(), bottom: (values[3] as num).toDouble()));
        });
      },
      onLoadStop: (_, __) {
        _webLoaded = true;
        _applyPayload();
      },
    ));
  }

  Future<void> _applyPayload() async {
    final controller = _controller;
    if (controller == null || !_webLoaded) {
      return;
    }
    final encodedPayloadLiteral = jsonEncode(jsonEncode({
      ...widget.document.toJson(), '_observationRevision': _observationRevision,
    }));
    await controller.evaluateJavascript(
      source: 'window.applyGraphPayload($encodedPayloadLiteral);',
    );
  }
}
