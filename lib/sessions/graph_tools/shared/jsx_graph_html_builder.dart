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
      const initialPayload = $payload;
      let board = null;
      let homeBounds = [-8, 8, 8, -8];
      let activeScope = null;
      let activeRenderSignature = '';
      let pendingPayload = null;
      let renderScheduled = false;

      function toRadians(value) {
        return value * Math.PI / 180;
      }

      function toDegrees(value) {
        return value * 180 / Math.PI;
      }

      function createScope(settings) {
        const degreeMode = settings.degreeMode === true;
        const parameters = Array.isArray(settings.parameters) ? settings.parameters : [];
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
        expression = expression
          .replace(/×/g, '*')
          .replace(/÷/g, '/')
          .replace(/−/g, '-')
          .replace(/π/g, 'pi');
        expression = expression.replace(/\\bPI\\b/gi, 'pi');
        expression = expression.replace(/\\bE\\b/gi, 'e');
        expression = insertImplicitMultiplication(expression);
        expression = expression.replace(/\\^/g, '**');
        return expression;
      }

      function tokenizeExpression(source) {
        const tokens = [];
        let index = 0;
        while (index < source.length) {
          const char = source[index];
          if (/\\s/.test(char)) {
            index += 1;
            continue;
          }
          if (/[0-9.]/.test(char)) {
            const start = index;
            index += 1;
            while (index < source.length && /[0-9.]/.test(source[index])) {
              index += 1;
            }
            tokens.push({ text: source.slice(start, index), kind: 'number' });
            continue;
          }
          if (/[A-Za-z_]/.test(char)) {
            const start = index;
            index += 1;
            while (index < source.length && /[A-Za-z0-9_]/.test(source[index])) {
              index += 1;
            }
            tokens.push({ text: source.slice(start, index), kind: 'identifier' });
            continue;
          }
          if (char === '(') {
            tokens.push({ text: char, kind: 'open' });
          } else if (char === ')') {
            tokens.push({ text: char, kind: 'close' });
          } else {
            tokens.push({ text: char, kind: 'operator' });
          }
          index += 1;
        }
        return tokens;
      }

      const functionNames = new Set([
        'abs', 'acos', 'asin', 'atan', 'ceil', 'cos', 'exp', 'floor',
        'ln', 'log', 'max', 'min', 'pow', 'round', 'sin', 'sqrt', 'tan',
      ]);

      function canEndFactor(token) {
        return token.kind === 'number' || token.kind === 'identifier' || token.kind === 'close';
      }

      function canStartFactor(token) {
        return token.kind === 'number' || token.kind === 'identifier' || token.kind === 'open';
      }

      function needsMultiplication(left, right) {
        if (!canEndFactor(left) || !canStartFactor(right)) return false;
        if (
          left.kind === 'identifier' &&
          right.kind === 'open' &&
          functionNames.has(left.text.toLowerCase())
        ) {
          return false;
        }
        return true;
      }

      function insertImplicitMultiplication(source) {
        const tokens = tokenizeExpression(source);
        if (tokens.length < 2) return source.replace(/\\s+/g, '');
        let out = '';
        for (let index = 0; index < tokens.length; index += 1) {
          if (index > 0 && needsMultiplication(tokens[index - 1], tokens[index])) {
            out += '*';
          }
          out += tokens[index].text;
        }
        return out;
      }

      function compileExpression(expression, scope) {
        const normalized = normalizeExpression(expression);
        return new Function('x', 'scope', 'with (scope) { return (' + normalized + '); }');
      }

      function graphRenderSignature(payload) {
        const settings = payload && payload.settings ? payload.settings : {};
        const viewport = settings.viewport || { left: -8, right: 8, top: 8, bottom: -8 };
        const parameters = Array.isArray(settings.parameters) ? settings.parameters : [];
        const items = Array.isArray(payload && payload.items) ? payload.items : [];
        return JSON.stringify({
          settings: {
            showAxes: settings.showAxes !== false,
            showGrid: settings.showGrid !== false,
            lockViewport: settings.lockViewport === true,
            degreeMode: settings.degreeMode === true,
            viewport: {
              left: Number(viewport.left),
              right: Number(viewport.right),
              top: Number(viewport.top),
              bottom: Number(viewport.bottom),
            },
            parameterIds: parameters.map((parameter) => String(parameter.id || '').trim()),
          },
          items: items.map((item) => ({
            id: item && item.id,
            type: item && item.type,
            enabled: item && item.enabled !== false,
            expression: item && item.expression,
            colorHex: item && item.colorHex,
            xValues: item && item.xValues,
            yValues: item && item.yValues,
          })),
        });
      }

      function applyParameterValues(scope, settings) {
        const parameters = Array.isArray(settings.parameters) ? settings.parameters : [];
        for (const parameter of parameters) {
          const id = String(parameter.id || '').trim();
          if (id.length > 0) {
            scope[id] = Number(parameter.value);
          }
        }
      }

      function updateGraphParameters(payload) {
        if (board === null || activeScope === null) return false;
        const settings = payload && payload.settings ? payload.settings : {};
        const nextSignature = graphRenderSignature(payload);
        if (nextSignature !== activeRenderSignature) return false;
        applyParameterValues(activeScope, settings);
        board.update();
        return true;
      }

      function renderGraph(payload) {
        if (updateGraphParameters(payload)) return;

        const settings = payload && payload.settings ? payload.settings : {};
        const items = Array.isArray(payload && payload.items)
          ? payload.items.filter((item) => item && item.enabled !== false)
          : [];
        const viewport = settings.viewport || { left: -8, right: 8, top: 8, bottom: -8 };

        homeBounds = [
          Number(viewport.left),
          Number(viewport.top),
          Number(viewport.right),
          Number(viewport.bottom),
        ];

        if (board !== null) {
          JXG.JSXGraph.freeBoard(board);
          board = null;
        }

        board = JXG.JSXGraph.initBoard('box', {
          axis: settings.showAxes !== false,
          boundingbox: homeBounds,
          grid: settings.showGrid !== false ? { gridX: 1, gridY: 1 } : false,
          keepAspectRatio: true,
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

        const scope = createScope(settings);
        activeScope = scope;
        activeRenderSignature = graphRenderSignature(payload);

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
      }

      window.applyGraphPayload = function(payloadJson) {
        try {
          const nextPayload = typeof payloadJson === 'string'
            ? JSON.parse(payloadJson)
            : payloadJson;
          if (!nextPayload || typeof nextPayload !== 'object') return;
          pendingPayload = nextPayload;
          if (renderScheduled) return;
          renderScheduled = true;
          window.requestAnimationFrame(function() {
            renderScheduled = false;
            if (pendingPayload !== null) {
              renderGraph(pendingPayload);
              pendingPayload = null;
            }
          });
        } catch (_) {
          // Ignore non-graph messages from the host page.
        }
      };

      window.addEventListener('message', function(event) {
        window.applyGraphPayload(event.data);
      });

      renderGraph(initialPayload);

      document.getElementById('zoom-in').addEventListener('click', function() {
        if (board !== null) board.zoomIn();
      });

      document.getElementById('zoom-out').addEventListener('click', function() {
        if (board !== null) board.zoomOut();
      });

      document.getElementById('zoom-home').addEventListener('click', function() {
        if (board !== null) board.setBoundingBox(homeBounds, true);
      });
    </script>
  </body>
</html>
''';
}
