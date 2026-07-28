import 'package:flutter/material.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

import 'jsx_graph_embed_stub.dart'
    if (dart.library.html) 'jsx_graph_embed_web.dart'
    if (dart.library.io) 'jsx_graph_embed_native.dart';

/// 필요한 변수는 그래프 문서와 내부 매개변수 조작부 표시 여부다.
/// 작동 원리는 교재에서는 iframe 안의 실습 슬라이더를 유지하고,
/// 직접 그리기 화면에서는 Flutter 편집 패널과 중복되지 않도록 숨긴다.
Widget buildJsxGraphEmbed(
  AiFlowGraphDocument document, {
  Key? key,
  bool showParameterControls = true,
  bool directManipulationMode = false,
  bool forceCanvasRenderer = false,
}) => buildJsxGraphEmbedImpl(
  document,
  key: key,
  showParameterControls: showParameterControls,
  directManipulationMode: directManipulationMode,
  forceCanvasRenderer: forceCanvasRenderer,
);
