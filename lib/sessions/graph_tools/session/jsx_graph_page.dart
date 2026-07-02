import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:s11/shared/utils/ui_scale.dart';

import 'package:s11/sessions/graph_tools/ui/widgets/jsx_graph_embed.dart';
import 'package:s11/shared/theme/app_colors.dart';

const _kGreen = AppColors.primary;
const _kWhite = Colors.white;

class JsxGraphPage extends StatefulWidget {
  const JsxGraphPage({super.key});

  @override
  State<JsxGraphPage> createState() => _JsxGraphPageState();
}

class _JsxGraphPageState extends State<JsxGraphPage> {
  final TextEditingController _expressionController = TextEditingController(
    text: 'sin(x)',
  );
  String _currentExpression = 'sin(x)';
  int _graphVersion = 0;
  bool _showAxis = false;

  @override
  void dispose() {
    _expressionController.dispose();
    super.dispose();
  }

  String _escapeForJsString(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  }

  String _buildHtml(String expression) {
    final escapedExpr = _escapeForJsString(expression.trim());
    return '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="stylesheet" href="https://jsxgraph.org/distrib/jsxgraph.css" />
    <script src="https://jsxgraph.org/distrib/jsxgraphcore.js"></script>
    <style>
      html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #ffffff; }
      #box { width: 100%; height: 100%; }
      #error {
        position: fixed; left: 12px; bottom: 12px; right: 12px;
        padding: 8px 12px; border-radius: 8px;
        color: #b00020; background: #ffe6ea;
        font-family: sans-serif; font-size: 13px;
      }
    </style>
  </head>
  <body>
    <div id="box" class="jxgbox"></div>
    <script>
      const rawExpr = '$escapedExpr';

      function normalizeExpr(expr) {
        let s = expr.trim();
        s = s.replace(/\\bpi\\b/gi, 'Math.PI');
        s = s.replace(/\\be\\b/g, 'Math.E');
        s = s.replace(
          /\\b(sin|cos|tan|asin|acos|atan|sqrt|abs|exp|log|pow|floor|ceil|round|max|min)\\s*\\(/gi,
          function(_, fnName) { return 'Math.' + fnName + '('; }
        );
        return s;
      }

      try {
        const board = JXG.JSXGraph.initBoard('box', {
          boundingbox: [-10, 10, 10, -10],
          axis: ${_showAxis ? 'true' : 'false'},
          grid: false,
          showNavigation: true,
          showCopyright: false
        });

        const expr = normalizeExpr(rawExpr);
        const fn = new Function('x', 'return (' + expr + ');');

        board.create('functiongraph', [function(x) { return fn(x); }], {
          strokeWidth: 3,
          strokeColor: '#000000'
        });
      } catch (e) {
        const error = document.createElement('div');
        error.id = 'error';
        error.textContent = '식 오류: ' + (e && e.message ? e.message : e);
        document.body.appendChild(error);
      }
    </script>
  </body>
</html>
''';
  }

  void _drawGraph() {
    final input = _expressionController.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _currentExpression = input;
      _graphVersion += 1;
    });
  }

  void _setExample(String expression) {
    _expressionController.text = expression;
    _drawGraph();
  }

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    final isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

    return Scaffold(
      backgroundColor: _kWhite,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(72 * scale),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 72 * scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: _kGreen),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Text(
                  '에이아이플로우',
                  style: TextStyle(
                    color: _kGreen,
                    fontSize: 36 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Positioned(
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.info_outline, color: _kGreen),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('그래프 도움말'),
                          content: const SelectableText(
                            '예시: sin(x), x*x, sqrt(x), log(x), abs(x), exp(x)\n'
                            'x*x는 x^2, x*x*x는 x^3입니다.\n'
                            'CDN: https://jsxgraph.org/distrib/jsxgraphcore.js',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('닫기'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: isLinux
          ? const Center(child: Text('이 그래프 웹뷰는 Linux에서 지원되지 않습니다.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _expressionController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _drawGraph(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '함수 f(x)',
                            hintText: '예: sin(x), x*x+2*x-1, sqrt(x)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _drawGraph,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('그리기'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ExampleChip(text: 'sin(x)', onTap: _setExample),
                      _ExampleChip(text: 'x*x', onTap: _setExample),
                      _ExampleChip(text: 'x*x*x-2*x', onTap: _setExample),
                      _ExampleChip(text: 'sqrt(x)', onTap: _setExample),
                      _ExampleChip(text: 'abs(x)', onTap: _setExample),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('축 표시'),
                  value: _showAxis,
                  onChanged: (value) {
                    setState(() {
                      _showAxis = value;
                      _graphVersion += 1;
                    });
                  },
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: buildJsxGraphEmbed(
                    _buildHtml(_currentExpression),
                    key: ValueKey('graph-$_graphVersion'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, required this.onTap});

  final String text;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(label: Text(text), onPressed: () => onTap(text)),
    );
  }
}
