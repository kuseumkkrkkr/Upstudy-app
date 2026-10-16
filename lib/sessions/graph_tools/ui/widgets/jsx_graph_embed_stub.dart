import 'package:flutter/material.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

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
  return Center(key: key, child: Text('현재 플랫폼에서는 그래프 보기를 지원하지 않습니다.'));
}
