import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';
import 'package:s11/sessions/graph_tools/shared/graph_parameter_observation.dart';

// Dart dynamic equality may probe cross-origin Window properties. JS identity
// compares WindowProxy references without weakening the iframe sandbox.
@JS('Object.is')
external JSBoolean _sameGraphWindow(JSAny? first, JSAny? second);

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
}) => _JsxGraphEmbedWeb(
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

class _JsxGraphEmbedWeb extends StatefulWidget {
  const _JsxGraphEmbedWeb({
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
  State<_JsxGraphEmbedWeb> createState() => _JsxGraphEmbedWebState();
}

class _JsxGraphEmbedWebState extends State<_JsxGraphEmbedWeb> {
  static int _viewTypeSeed = 0;

  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final StreamSubscription<web.Event> _loadSubscription;
  late final StreamSubscription<web.MessageEvent> _messageSubscription;
  late String _payloadJson;
  int _observationRevision = 0;

  @override
  void initState() {
    super.initState();
    _payloadJson = jsonEncode(widget.document.toJson());
    _viewType = 'jsx-graph-${_viewTypeSeed++}';
    _iframe = web.HTMLIFrameElement()
      ..style.pointerEvents = widget.interactive ? 'auto' : 'none'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block';
    // No allow-same-origin: a graph can execute only our renderer, not access
    // the parent app's DOM, cookies or local storage. Messaging is source-bound.
    _iframe.setAttribute('sandbox', 'allow-scripts');
    _iframe.setAttribute('referrerpolicy', 'no-referrer');
    _setInteractive();
    _iframe.setAttribute(
      'srcdoc',
      buildAiFlowGraphHtml(
        widget.document,
        showParameterControls: widget.showParameterControls,
        directManipulationMode: widget.directManipulationMode,
      ),
    );
    _loadSubscription = _iframe.onLoad.listen((_) => _postLatestPayload());
    _messageSubscription = web.window.onMessage.listen((event) {
      if (!_sameGraphWindow(event.source, _iframe.contentWindow).toDart || !event.data.isA<JSString>()) return;
      try {
        final data = jsonDecode((event.data as JSString).toDart);
        if (data is Map && data['type'] == 'aiflow-parameters') {
          if (!mounted || !widget.interactive) return;
          final values = readGraphParameterEvent(widget.document, data, _observationRevision);
          if (values != null) widget.onParametersChanged?.call(values);
          return;
        }
        if (data is! Map || data['type'] != 'aiflow-viewport') return;
        final values = ['left', 'right', 'top', 'bottom'].map((key) => data[key]).toList();
        if (values.any((value) => value is! num || !value.isFinite)) return;
        if (values[0] >= values[1] || values[3] >= values[2]) return;
        widget.onViewportChanged?.call(AiFlowGraphViewport(left: (values[0] as num).toDouble(), right: (values[1] as num).toDouble(), top: (values[2] as num).toDouble(), bottom: (values[3] as num).toDouble()));
      } on FormatException {
        // Ignore unrelated or malformed iframe messages.
      }
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });
  }

  @override
  void didUpdateWidget(covariant _JsxGraphEmbedWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setInteractive();
    final nextPayloadJson = jsonEncode(widget.document.toJson());
    if (_payloadJson != nextPayloadJson) {
      _payloadJson = nextPayloadJson;
      _observationRevision++;
      _postLatestPayload();
    }
    if (widget.commandRevision != oldWidget.commandRevision && widget.command != null) {
      _iframe.contentWindow?.postMessage(jsonEncode({'type': 'aiflow-command', 'command': widget.command}).toJS, '*'.toJS);
    }
  }

  /// Modal backgrounds cannot receive pointer or keyboard focus.
  void _setInteractive() {
    _iframe.style.pointerEvents = widget.interactive ? 'auto' : 'none';
    if (widget.interactive) {
      _iframe.removeAttribute('inert');
    } else {
      _iframe.setAttribute('inert', '');
    }
  }

  /// 필요한 변수는 iframe의 현재 창과 마지막으로 직렬화한 그래프 문서다.
  /// 작동 원리는 모바일에서 iframe 로드 전 입력된 수식도 load 이벤트 직후 다시
  /// 보내어 JSXGraph가 빈 초기 문서로 남는 상황을 막는 것이다.
  void _postLatestPayload() {
    _iframe.contentWindow?.postMessage(jsonEncode({
      ...widget.document.toJson(), '_observationRevision': _observationRevision,
    }).toJS, '*'.toJS);
  }

  /// 필요한 변수는 현재 iframe DOM 요소다.
  /// 작동 원리는 교재 페이지를 떠날 때 플랫폼 뷰를 즉시 숨기고 DOM에서 제거해 다음 Flutter 장면에 합성 레이어가 남지 않게 한다.
  @override
  void dispose() {
    _loadSubscription.cancel();
    _messageSubscription.cancel();
    _iframe.style.display = 'none';
    _iframe.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
