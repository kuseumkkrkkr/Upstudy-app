import 'package:flutter/material.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

import 'jsx_graph_embed_stub.dart'
    if (dart.library.html) 'jsx_graph_embed_web.dart'
    if (dart.library.io) 'jsx_graph_embed_native.dart';

Widget buildJsxGraphEmbed(AiFlowGraphDocument document, {Key? key}) =>
    buildJsxGraphEmbedImpl(document, key: key);
