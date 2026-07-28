import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

Widget buildJsxGraphEmbedImpl(
  AiFlowGraphDocument document, {
  Key? key,
  bool showParameterControls = true,
  bool directManipulationMode = false,
}) => _JsxGraphEmbedWeb(
  key: key,
  document: document,
  showParameterControls: showParameterControls,
  directManipulationMode: directManipulationMode,
);

class _JsxGraphEmbedWeb extends StatefulWidget {
  const _JsxGraphEmbedWeb({
    super.key,
    required this.document,
    required this.showParameterControls,
    required this.directManipulationMode,
  });

  final AiFlowGraphDocument document;
  final bool showParameterControls;
  final bool directManipulationMode;

  @override
  State<_JsxGraphEmbedWeb> createState() => _JsxGraphEmbedWebState();
}

class _JsxGraphEmbedWebState extends State<_JsxGraphEmbedWeb> {
  static int _viewTypeSeed = 0;

  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final StreamSubscription<web.Event> _loadSubscription;
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
    _iframe.setAttribute(
      'srcdoc',
      buildAiFlowGraphHtml(
        widget.document,
        showParameterControls: widget.showParameterControls,
        directManipulationMode: widget.directManipulationMode,
      ),
    );
    _loadSubscription = _iframe.onLoad.listen((_) => _postLatestPayload());

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
      _postLatestPayload();
    }
  }

  /// 필요한 변수는 iframe의 현재 창과 마지막으로 직렬화한 그래프 문서다.
  /// 작동 원리는 모바일에서 iframe 로드 전 입력된 수식도 load 이벤트 직후 다시
  /// 보내어 JSXGraph가 빈 초기 문서로 남는 상황을 막는 것이다.
  void _postLatestPayload() {
    _iframe.contentWindow?.postMessage(_payloadJson.toJS, '*'.toJS);
  }

  /// 필요한 변수는 현재 iframe DOM 요소다.
  /// 작동 원리는 교재 페이지를 떠날 때 플랫폼 뷰를 즉시 숨기고 DOM에서 제거해 다음 Flutter 장면에 합성 레이어가 남지 않게 한다.
  @override
  void dispose() {
    _loadSubscription.cancel();
    _iframe.style.display = 'none';
    _iframe.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
