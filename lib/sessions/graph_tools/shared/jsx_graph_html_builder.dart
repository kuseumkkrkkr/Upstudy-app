import 'dart:convert';

import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

String buildAiFlowGraphHtml(AiFlowGraphDocument document) {
  final payload = jsonEncode(document.toJson());

  return '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="stylesheet" href="https://jsxgraph.org/distrib/jsxgraph.css" />
    <script src="https://jsxgraph.org/distrib/jsxgraphcore.js"></script>
    <style>
      * { box-sizing: border-box; }

      html, body {
        margin: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: #ffffff;
      }

      #app {
        position: relative;
        width: 100%;
        height: 100%;
      }

      #box {
        width: 100%;
        height: 100%;
      }

      .toolbar {
        position: absolute;
        top: 14px;
        right: 14px;
        z-index: 9;
        display: flex;
        flex-direction: column;
        gap: 8px;
        padding: 8px;
        border-radius: 16px;
        border: 1px solid rgba(22, 53, 36, 0.12);
        background: rgba(255, 255, 255, 0.96);
        box-shadow: 0 12px 28px rgba(27, 64, 43, 0.10);
      }

      .tool-button {
        appearance: none;
        border: 0;
        width: 38px;
        height: 38px;
        border-radius: 12px;
        background: #f3f7f4;
        color: #1b402b;
        font-size: 20px;
        font-weight: 700;
        cursor: pointer;
      }

      .tool-button:hover {
        background: #eaf2ec;
      }
    </style>
  </head>
  <body>
    <div id="app">
      <div id="box" class="jxgbox"></div>
      <div class="toolbar">
        <button class="tool-button" id="zoom-in" title="Zoom in">+</button>
        <button class="tool-button" id="zoom-out" title="Zoom out">−</button>
        <button class="tool-button" id="zoom-home" title="Reset view">⌂</button>
      </div>
    </div>
    <script>
      const payload = $payload;
      const settings = payload.settings || {};
      const items = Array.isArray(payload.items)
        ? payload.items.filter((item) => item && item.enabled !== false)
        : [];
      const parameters = Array.isArray(settings.parameters) ? settings.parameters : [];
      const viewport = settings.viewport || { left: -8, right: 8, top: 8, bottom: -8 };

      function toRadians(value) {
        return value * Math.PI / 180;
      }

      function toDegrees(value) {
        return value * 180 / Math.PI;
      }

      function createScope() {
        const degreeMode = settings.degreeMode === true;
        const scope = {
          abs: Math.abs,
          acos: degreeMode ? (value) => toDegrees(Math.acos(value)) : Math.acos,
          asin: degreeMode ? (value) => toDegrees(Math.asin(value)) : Math.asin,
          atan: degreeMode ? (value) => toDegrees(Math.atan(value)) : Math.atan,
          ceil: Math.ceil,
          cos: degreeMode ? (value) => Math.cos(toRadians(value)) : Math.cos,
          e: Math.E,
          exp: Math.exp,
          floor: Math.floor,
          ln: Math.log,
          log: (value) => Math.log10(value),
          max: Math.max,
          min: Math.min,
          pi: Math.PI,
          pow: Math.pow,
          round: Math.round,
          sin: degreeMode ? (value) => Math.sin(toRadians(value)) : Math.sin,
          sqrt: Math.sqrt,
          tan: degreeMode ? (value) => Math.tan(toRadians(value)) : Math.tan,
        };

        for (const parameter of parameters) {
          const id = String(parameter.id || '').trim();
          if (id.length > 0) {
            scope[id] = Number(parameter.value);
          }
        }

        return scope;
      }

      function normalizeExpression(source) {
        let expression = String(source || '').trim();
        expression = expression.replace(/^y\\s*=\\s*/i, '');
        expression = expression.replace(/\\bPI\\b/gi, 'pi');
        expression = expression.replace(/\\bE\\b/gi, 'e');
        expression = expression.replace(/\\^/g, '**');
        return expression;
      }

      function compileExpression(expression, scope) {
        const normalized = normalizeExpression(expression);
        return new Function('x', 'scope', 'with (scope) { return (' + normalized + '); }');
      }

      const scope = createScope();
      const homeBounds = [
        Number(viewport.left),
        Number(viewport.top),
        Number(viewport.right),
        Number(viewport.bottom),
      ];

      const board = JXG.JSXGraph.initBoard('box', {
        axis: settings.showAxes !== false,
        boundingbox: homeBounds,
        grid: settings.showGrid !== false,
        keepAspectRatio: false,
        pan: {
          enabled: settings.lockViewport !== true,
          needShift: false,
        },
        zoom: {
          enabled: settings.lockViewport !== true,
          needShift: false,
          pinch: settings.lockViewport !== true,
          wheel: settings.lockViewport !== true,
          factorX: 1.08,
          factorY: 1.08,
          min: 0.2,
          max: 40,
        },
        showNavigation: false,
        showCopyright: false,
      });

      for (const item of items) {
        if (item.type === 'function' && String(item.expression || '').trim().length > 0) {
          const evaluator = compileExpression(item.expression, scope);
          board.create('functiongraph', [
            function(x) {
              return evaluator(x, scope);
            },
          ], {
            fixed: settings.lockViewport === true,
            highlight: true,
            strokeColor: item.colorHex || '#1b402b',
            strokeWidth: 3,
          });
          continue;
        }

        if (
          item.type === 'line' &&
          Array.isArray(item.xValues) &&
          Array.isArray(item.yValues)
        ) {
          board.create('curve', [item.xValues, item.yValues], {
            fixed: settings.lockViewport === true,
            highlight: true,
            strokeColor: item.colorHex || '#1b402b',
            strokeWidth: 3,
          });
          continue;
        }

        if (
          item.type === 'scatter' &&
          Array.isArray(item.xValues) &&
          Array.isArray(item.yValues)
        ) {
          const length = Math.min(item.xValues.length, item.yValues.length);
          for (let index = 0; index < length; index += 1) {
            board.create('point', [Number(item.xValues[index]), Number(item.yValues[index])], {
              fixed: settings.lockViewport === true,
              face: 'o',
              size: 3.5,
              strokeColor: item.colorHex || '#1b402b',
              fillColor: item.colorHex || '#1b402b',
              name: '',
              withLabel: false,
            });
          }
        }
      }

      document.getElementById('zoom-in').addEventListener('click', function() {
        board.zoomIn();
      });

      document.getElementById('zoom-out').addEventListener('click', function() {
        board.zoomOut();
      });

      document.getElementById('zoom-home').addEventListener('click', function() {
        board.setBoundingBox(homeBounds, true);
      });
    </script>
  </body>
</html>
''';
}
