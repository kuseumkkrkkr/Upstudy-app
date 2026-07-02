import 'package:flutter/material.dart';

import 'jsx_graph_embed_stub.dart'
    if (dart.library.html) 'jsx_graph_embed_web.dart'
    if (dart.library.io) 'jsx_graph_embed_native.dart';

Widget buildJsxGraphEmbed(String html, {Key? key}) =>
    buildJsxGraphEmbedImpl(html, key: key);
