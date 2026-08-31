import 'dart:convert';

import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

/// 필요한 변수는 렌더링 대상 그래프 문서·매개변수 조작부·직접 조작 모드다.
/// 작동 원리는 문서를 JSON payload로 주입해 웹뷰 내부에서 한 번만 초기 렌더링하고,
/// 직접 그리기에서만 격자 위의 +/-를 남기면서 교재의 기존 조작부는 유지하는 것이다.
String buildAiFlowGraphHtml(
  AiFlowGraphDocument document, {
  bool showParameterControls = true,
  bool directManipulationMode = false,
}) {
  final payloadJson = jsonEncode(document.toJson());
  final escapedPayload = payloadJson
      .replaceAll(r'\\', r'\\\\')
      .replaceAll(r"'", r"\\'")
      .replaceAll('\n', r'\\n')
      .replaceAll('\r', r'\\r');
  return r'''
<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AIFlow Graph</title>
    <link
      rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/jsxgraph@1.13.1/distrib/jsxgraph.css"
    />
    <script
      id="jsxgraph-script"
      src="https://cdn.jsdelivr.net/npm/jsxgraph@1.13.1/distrib/jsxgraphcore.js"
      async
    ></script>
    <style>
      :root {
        color-scheme: light;
      }
      html,
      body {
        margin: 0;
        width: 100%;
        height: 100%;
        background: transparent;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }
      body {
        overflow: hidden;
      }
      #app {
        width: 100%;
        height: 100%;
        display: flex;
        flex-direction: column;
        gap: 8px;
        position: relative;
      }
      #board {
        width: 100%;
        height: 100%;
        box-sizing: border-box;
        min-height: 120px;
        position: relative;
        overflow: hidden;
        touch-action: none;
        border: 1px solid #d6e2d7;
        border-radius: 8px;
        background: #ffffff;
      }
      #graphHost {
        width: 100%;
        height: 220px;
        flex: 1 1 auto;
        min-height: 120px;
        border-radius: 8px;
        overflow: hidden;
        position: relative;
      }
      #fallbackCanvas {
        display: none;
        width: 100%;
        height: 100%;
        margin: 0;
      }
      #fallbackCanvas[hidden] {
        display: none !important;
      }
      #controls {
        width: 100%;
        min-height: 48px;
        max-height: 88px;
        overflow-y: auto;
        padding: 4px 0 0 0;
        display: __AIFLOW_GRAPH_CONTROLS_DISPLAY__;
        gap: 8px;
        flex-wrap: wrap;
        align-items: flex-start;
      }
      #status {
        min-height: 15px;
        font-size: 11px;
        line-height: 1.45;
        color: #556f63;
      }
      .slider-item {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 11px;
        color: #2f4c3d;
        padding: 4px 6px;
        border: 1px solid #e0ebdf;
        border-radius: 999px;
        background: #f7fbf8;
      }
      .slider-label {
        white-space: nowrap;
        color: #355b4b;
        min-width: 56px;
      }
      input[type='range'] {
        width: 160px;
        accent-color: #2f6f4f;
      }
      .slider-value {
        min-width: 52px;
        text-align: right;
        font-weight: 700;
        color: #234535;
      }
      .toolbar {
        display: flex;
        gap: 6px;
      }
      .toolbar button {
        border: 1px solid #c9dbc9;
        border-radius: 999px;
        background: #ffffff;
        color: #2f4c3d;
        font-size: 11px;
        height: 24px;
        padding: 0 10px;
        cursor: pointer;
      }
      .toolbar button:hover {
        background: #f0f5f1;
      }
      .compact-label {
        display: none;
      }
      body.direct-drawing #app {
        gap: 0;
      }
      body.direct-drawing #status {
        display: none;
      }
      body.direct-drawing .toolbar {
        position: absolute;
        right: 12px;
        bottom: 12px;
        z-index: 20;
        gap: 4px;
      }
      body.direct-drawing .toolbar button {
        width: 36px;
        height: 36px;
        padding: 0;
        border-color: #d9d9dd;
        background: rgba(255, 255, 255, 0.94);
        color: #202022;
        font-size: 20px;
        font-weight: 500;
        box-shadow: 0 5px 14px rgba(32, 32, 34, 0.10);
      }
      body.direct-drawing .toolbar .reset-control,
      body.direct-drawing .long-label {
        display: none;
      }
      body.direct-drawing .compact-label {
        display: inline;
      }
      body.direct-drawing #graphHost,
      body.direct-drawing #board {
        border-radius: 0;
      }
      .fallback {
        width: 100%;
        height: 100%;
        box-sizing: border-box;
        display: flex;
        align-items: center;
        justify-content: center;
        text-align: center;
        color: #4d5d55;
        padding: 20px;
        line-height: 1.5;
      }
      .equation {
        font-size: 11px;
        color: #1f6b4e;
        padding: 0 6px;
      }
    </style>
  </head>
  <body class="__AIFLOW_GRAPH_BODY_CLASS__">
    <div id="app">
      <div id="status"></div>
      <div class="toolbar">
        <button id="zoomInBtn" aria-label="확대"><span class="long-label">확대</span><span class="compact-label">+</span></button>
        <button id="zoomOutBtn" aria-label="축소"><span class="long-label">축소</span><span class="compact-label">−</span></button>
        <button id="resetBtn" class="reset-control">초기화</button>
      </div>
      <div id="graphHost">
        <div id="board"></div>
        <canvas id="fallbackCanvas"></canvas>
      </div>
      <div id="controls" aria-label="파라미터 슬라이더"></div>
    </div>

    <script>
      (function() {
      const statusElement = document.getElementById('status');
      const graphHostElement = document.getElementById('graphHost');
        const boardElement = document.getElementById('board');
        const fallbackCanvasElement = document.getElementById('fallbackCanvas');
        const controlsElement = document.getElementById('controls');
        const zoomInBtn = document.getElementById('zoomInBtn');
        const zoomOutBtn = document.getElementById('zoomOutBtn');
        const resetBtn = document.getElementById('resetBtn');

        let initialPayload = {};
        try {
          initialPayload = JSON.parse('__AIFLOW_GRAPH_PAYLOAD__');
        } catch (_) {
          setStatus('그래프 데이터 파싱 실패');
          initialPayload = {};
        }
      let board = null;
      let currentPayload = {};
      let renderedElements = [];
      let parameterValues = {};
        let initialViewport = null;
      let useFallback = false;
      let libraryLoadAttempted = false;
      let libraryLoadCompleted = false;

        const palette = {
          function: '#1B402B',
          line: '#245CFF',
          scatter: '#8B5CF6',
          grid: '#d9e6dd',
          axis: '#4a6257',
        };

        function setStatus(message) {
          if (!statusElement) return;
          statusElement.textContent = message || '';
        }

        function numberOrFallback(value, fallback) {
          const n = Number(value);
          return Number.isFinite(n) ? n : fallback;
        }

        function formatFixed(value) {
          if (!Number.isFinite(value)) return '';
          if (Math.abs(value) > 1000000) {
            return value.toExponential(2);
          }
          return Number(value.toFixed(10))
            .toString()
            .replace(/\.0+\$/, '')
            .replace(/(\.\d*?)0+\$/, function (_, capture) {
              return capture;
            })
            .replace(/\.\$/, '');
        }

        function getViewport(payload) {
          const viewport = payload?.settings?.viewport;
          const left = numberOrFallback(viewport?.left, -8);
          const right = numberOrFallback(viewport?.right, 8);
          const top = numberOrFallback(viewport?.top, 8);
          const bottom = numberOrFallback(viewport?.bottom, -8);
          return { left, right, top, bottom };
        }

        function ensureFallbackCanvasSize() {
          const width = graphHostElement.clientWidth || 320;
          const height = graphHostElement.clientHeight || 220;
          const ratio = window.devicePixelRatio || 1;
          fallbackCanvasElement.width = Math.max(1, Math.floor(width * ratio));
          fallbackCanvasElement.height = Math.max(1, Math.floor(height * ratio));
          fallbackCanvasElement.style.width = width + 'px';
          fallbackCanvasElement.style.height = height + 'px';
          return { width, height, ratio };
        }

        function setRenderMode(nextFallback) {
          useFallback = nextFallback === true;
          if (useFallback) {
            boardElement.style.display = 'none';
            fallbackCanvasElement.style.display = 'block';
          } else {
            boardElement.style.display = 'block';
            fallbackCanvasElement.style.display = 'none';
            fallbackCanvasElement.style.display = 'none';
            if (board) {
              board.fullUpdate && board.fullUpdate();
            }
          }
        }

        function buildFormulaMap() {
          const map = Object.create(null);
          if (!currentPayload?.settings?.parameters) return map;
          for (const parameter of currentPayload.settings.parameters) {
            if (!parameter?.id) continue;
            map[String(parameter.id)] = numberOrFallback(parameter.value, 0);
          }
          return map;
        }

        function normalizeExpression(source) {
          if (typeof source !== 'string') return '';
          let value = source.trim();
          if (!value) return '';
          value = value.replace(/^\s*y\s*=\s*/i, '');
          value = value
            .replace(/×/g, '*')
            .replace(/÷/g, '/')
            .replace(/−/g, '-')
            .replace(/π/g, 'pi')
            .replace(/PI/g, 'pi')
            .replace(/\bE\b/g, 'e');
          return value.replace(/\^/g, '**');
        }

        function safeFunctionFromExpression(expression, degreeMode) {
          const normalized = normalizeExpression(expression || '');
          if (!normalized) return null;
          try {
            const fnBody = 'with (scope) { return ' + normalized + '; }';
            const evaluator = new Function('scope', fnBody);
            return function(x) {
              const scope = Object.create(null);
              for (const [key, value] of Object.entries(parameterValues)) {
                scope[key] = Number(value);
              }
              scope.x = Number(x);
              scope.pi = Math.PI;
              scope.e = Math.E;
              scope.abs = Math.abs;
              scope.max = Math.max;
              scope.min = Math.min;
              scope.sqrt = Math.sqrt;
              scope.pow = Math.pow;
              scope.exp = Math.exp;
              scope.ln = Math.log;
              scope.log = function(v) { return Math.log(v) / Math.LN10; };
              scope.sin = degreeMode ? function(v) {
                return Math.sin(v * Math.PI / 180);
              } : Math.sin;
              scope.cos = degreeMode ? function(v) {
                return Math.cos(v * Math.PI / 180);
              } : Math.cos;
              scope.tan = degreeMode ? function(v) {
                return Math.tan(v * Math.PI / 180);
              } : Math.tan;
              scope.ceil = Math.ceil;
              scope.floor = Math.floor;
              scope.round = Math.round;
              if (!Number.isFinite(scope.x)) return NaN;
              try {
                const value = evaluator(scope);
                return Number.isFinite(value) ? value : NaN;
              } catch (_) {
                return NaN;
              }
            };
          } catch (_) {
            return null;
          }
        }

        function clearElements() {
          if (!board) return;
          for (const item of renderedElements) {
            try {
              board.removeObject(item);
            } catch (_) {}
          }
          renderedElements = [];
          board.fullUpdate();
        }

        function xToCanvas(x, viewport, width, ratio) {
          return (x - viewport.left) * (width / (viewport.right - viewport.left)) * ratio;
        }

        function yToCanvas(y, viewport, height, ratio) {
          return (viewport.top - y) * (height / (viewport.top - viewport.bottom)) * ratio;
        }

        function drawFallbackGrid(ctx, width, height, viewport, ratio) {
          const padding = 32 * ratio;
          const plotWidth = Math.max(1, width - padding * 2);
          const plotHeight = Math.max(1, height - padding * 2);

          ctx.clearRect(0, 0, width, height);
          ctx.fillStyle = '#ffffff';
          ctx.fillRect(0, 0, width, height);

          const originX = padding;
          const originY = padding;
          const right = originX + plotWidth;
          const bottom = originY + plotHeight;

          const xRange = viewport.right - viewport.left;
          const yRange = viewport.top - viewport.bottom;
          const xStep = xRange / 10;
          const yStep = yRange / 8;

          ctx.strokeStyle = '#edf4ee';
          ctx.lineWidth = 1 * ratio;
          ctx.beginPath();
          for (let i = 0; i <= 10; i++) {
            const x = originX + (plotWidth / 10) * i;
            ctx.moveTo(x, originY);
            ctx.lineTo(x, bottom);
          }
          for (let i = 0; i <= 8; i++) {
            const y = originY + (plotHeight / 8) * i;
            ctx.moveTo(originX, y);
            ctx.lineTo(right, y);
          }
          ctx.stroke();

          ctx.strokeStyle = '#4a6257';
          ctx.lineWidth = 1.2 * ratio;
          const axisY = xToCanvas(0, viewport, plotWidth, ratio) + originX;
          const axisX = yToCanvas(0, viewport, plotHeight, ratio) + originY;
          if (axisY > originX - 1 && axisY < right + 1) {
            ctx.beginPath();
            ctx.moveTo(axisY, originY);
            ctx.lineTo(axisY, bottom);
            ctx.stroke();
          }
          if (axisX > originY - 1 && axisX < bottom + 1) {
            ctx.beginPath();
            ctx.moveTo(originX, axisX);
            ctx.lineTo(right, axisX);
            ctx.stroke();
          }

          ctx.fillStyle = '#3e5f4f';
          ctx.font =
              String(10 * ratio) +
              "px -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
          for (let i = 0; i <= 10; i++) {
            const xValue = viewport.left + xStep * i;
            const x = originX + (plotWidth / 10) * i;
            ctx.fillText(formatFixed(xValue), x - 10, bottom + 18 * ratio);
          }
          for (let i = 0; i <= 8; i++) {
            const yValue = viewport.top - yStep * i;
            const y = originY + (plotHeight / 8) * i;
            ctx.fillText(formatFixed(yValue), 2 * ratio, y + 4 * ratio);
          }

          return { originX, originY, right, bottom, plotWidth, plotHeight };
        }

        function drawFallback(payload) {
          const settings = payload?.settings || {};
          const items = Array.isArray(payload?.items) ? payload.items : [];
          const viewport = getViewport(payload);
          const params = settings.parameters || [];
          parameterValues = buildFormulaMap();
          const { width, height, ratio } = ensureFallbackCanvasSize();
          const ctx = fallbackCanvasElement.getContext('2d');
          if (!ctx) {
            return;
          }
          const bounds = drawFallbackGrid(
            ctx,
            width * ratio,
            height * ratio,
            { ...viewport },
            ratio,
          );
          const plotWidth = width * ratio - 64 * ratio;
          const plotHeight = height * ratio - 64 * ratio;
          let rendered = false;

          for (const item of items) {
            if (!item || item.enabled === false) continue;
            const type = item.type || 'function';
            if (type === 'function') {
              const color = item.colorHex || palette.function;
              const evaluator = safeFunctionFromExpression(
                item.expression || '',
                settings.degreeMode === true,
              );
              if (!evaluator) continue;

              ctx.strokeStyle = color;
              ctx.lineWidth = 2 * ratio;
              ctx.beginPath();
              const leftX = numberOrFallback(viewport.left, -8);
              const rightX = numberOrFallback(viewport.right, 8);
              const sampleCount = Math.max(240, Math.floor(plotWidth / (3 * ratio)));
              const step = (rightX - leftX) / sampleCount;
              let hasPoint = false;
              for (let i = 0; i <= sampleCount; i++) {
                const x = leftX + step * i;
                const y = evaluator(x);
                if (!Number.isFinite(y)) {
                  hasPoint = false;
                  continue;
                }
                const cx = bounds.originX + (width * ratio - 64 * ratio) * ((x - leftX) / (rightX - leftX));
                const cy = yToCanvas(y, viewport, height * ratio - 64 * ratio, 1) + 32 * ratio;
                if (!Number.isFinite(cx) || !Number.isFinite(cy)) {
                  hasPoint = false;
                  continue;
                }
                if (!hasPoint) {
                  ctx.moveTo(cx, cy);
                  hasPoint = true;
                } else {
                  ctx.lineTo(cx, cy);
                }
              }
              if (hasPoint) {
                ctx.stroke();
                rendered = true;
              }
              continue;
            }

            if (type === 'scatter' || type === 'line') {
              const color = item.colorHex || (type === 'line' ? palette.line : palette.scatter);
              const xValues = Array.isArray(item.xValues) ? item.xValues : [];
              const yValues = Array.isArray(item.yValues) ? item.yValues : [];
              const points = xValues
                .map((x, index) => [numberOrFallback(x, 0), numberOrFallback(yValues[index], NaN)])
                .filter((pair) => Number.isFinite(pair[0]) && Number.isFinite(pair[1]));
              if (points.length === 0) continue;
              if (type === 'line') {
                ctx.strokeStyle = color;
                ctx.lineWidth = 2 * ratio;
                ctx.beginPath();
                points.forEach((point, index) => {
                  const cx = bounds.originX + (plotWidth) * ((point[0] - viewport.left) / (viewport.right - viewport.left));
                  const cy = bounds.originY + (plotHeight) * ((viewport.top - point[1]) / (viewport.top - viewport.bottom));
                  if (index === 0) {
                    ctx.moveTo(cx, cy);
                  } else {
                    ctx.lineTo(cx, cy);
                  }
                });
                ctx.stroke();
                rendered = true;
              } else {
                const radius = 3 * ratio;
                points.forEach((point) => {
                  const cx = bounds.originX + (plotWidth) * ((point[0] - viewport.left) / (viewport.right - viewport.left));
                  const cy = bounds.originY + (plotHeight) * ((viewport.top - point[1]) / (viewport.top - viewport.bottom));
                  ctx.fillStyle = color;
                  ctx.beginPath();
                  ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                  ctx.fill();
                });
                rendered = true;
              }
            }
          }

          if (!rendered && params.length) {
            ctx.fillStyle = '#4d5d55';
            ctx.font =
                String(12 * ratio) +
                "px -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
            ctx.fillText(
              '현재 식으로는 즉시 렌더링 가능한 그래프가 없습니다.',
              30 * ratio,
              30 * ratio,
            );
          }
          if (!rendered && items.length === 0) {
            ctx.fillStyle = '#4d5d55';
            ctx.font =
                String(12 * ratio) +
                "px -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
            ctx.fillText('그래프 항목이 없습니다.', 30 * ratio, 30 * ratio);
          }

          if (params.length) {
            ctx.fillStyle = '#234535';
            ctx.font =
                String(11 * ratio) +
                "px -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
            const detail = params
              .map(
                (p) =>
                  (p.id || 'param') + '=' + formatFixed(numberOrFallback(p.value, 0)),
              )
              .join(', ');
            ctx.fillText('파라미터: ' + detail, 30 * ratio, 50 * ratio);
          }

          setStatus(rendered ? '파라미터/식 변경을 즉시 반영했습니다.' : '함수 식이 없어 미리보기를 제한합니다.');
        }

        function ensureBoard(payload) {
          if (!window.JXG) {
            setRenderMode(true);
            drawFallback(payload);
            return null;
          }
          const settings = payload.settings || {};
          const viewport = getViewport(payload);
          const options = {
            boundingbox: [viewport.left, viewport.top, viewport.right, viewport.bottom],
            keepAspectRatio: false,
            axis: settings.showAxes !== false,
            showCopyright: false,
            grid: settings.showGrid !== false,
            showNavigation: __AIFLOW_GRAPH_SHOW_NAVIGATION__,
            zoomX: settings.lockViewport !== true,
            zoomY: settings.lockViewport !== true,
            pan: {
              enabled: settings.lockViewport !== true,
            },
            zoom: {
              wheel: settings.lockViewport !== true,
              factorX: 1.08,
              factorY: 1.08,
            },
          };

          if (!boardElement) {
            return null;
          }
          board = JXG.JSXGraph.initBoard('board', options);
          board.renderer.container.style.background = 'white';
          initialViewport = [viewport.left, viewport.top, viewport.right, viewport.bottom];
          setRenderMode(false);
          return board;
        }

        function refreshBoardSize() {
          if (!board || !graphHostElement) return;
          const width = graphHostElement.clientWidth;
          const height = graphHostElement.clientHeight;
          if (width < 2 || height < 2) return;
          try {
            board.resizeContainer(width, height, true);
            board.fullUpdate();
          } catch (_) {}
        }

        if (window.ResizeObserver && graphHostElement) {
          const graphResizeObserver = new ResizeObserver(() => {
            window.requestAnimationFrame(refreshBoardSize);
          });
          graphResizeObserver.observe(graphHostElement);
        }
        window.addEventListener('resize', () => {
          window.requestAnimationFrame(refreshBoardSize);
        });

        function renderControls(parameters) {
          controlsElement.innerHTML = '';
          for (const parameter of parameters) {
            if (!parameter?.id) continue;
            const paramId = String(parameter.id);
            const min = numberOrFallback(parameter.min, -10);
            const max = numberOrFallback(parameter.max, 10);
            const step = numberOrFallback(parameter.step, 0.1);
            const initial = numberOrFallback(parameter.value, 0);
            const current = numberOrFallback(parameterValues[paramId], initial);
            parameterValues[paramId] = current;

            const row = document.createElement('label');
            row.className = 'slider-item';

            const label = document.createElement('span');
            label.className = 'slider-label';
            label.textContent = parameter.label || paramId;
            row.appendChild(label);

            const range = document.createElement('input');
            range.type = 'range';
            range.min = String(min);
            range.max = String(max);
            range.step = String(step);
            range.value = String(current);
            range.setAttribute('aria-label', paramId);
            row.appendChild(range);

            const valueLabel = document.createElement('span');
            valueLabel.className = 'slider-value';
            valueLabel.textContent = formatFixed(current);
            row.appendChild(valueLabel);

            range.addEventListener('input', () => {
              const next = numberOrFallback(range.value, current);
              parameterValues[paramId] = next;
              valueLabel.textContent = formatFixed(next);
              renderCurrentGraph();
            });

            controlsElement.appendChild(row);
          }
        }

        function applyAxesStyle() {
          if (!board) return;
          for (const axisId of ['xaxis', 'yaxis']) {
            const axis = board[axisId];
            if (axis) {
              axis.setAttribute({
                strokeColor: palette.axis,
                strokeWidth: 1.4,
              });
              if (axis.defaultTicks) {
                axis.defaultTicks.setAttribute({
                  strokeColor: palette.axis,
                });
              }
            }
          }
        }

        function renderCurrentGraph() {
          if (useFallback) {
            drawFallback(currentPayload);
            return;
          }
          if (!board) return;
          clearElements();

          const settings = currentPayload.settings || {};
          const items = currentPayload.items || [];
          const functionItems = [];
          let hasRenderable = false;

          for (const item of items) {
            if (!item || item.enabled === false) continue;
            const type = item.type || 'function';
            if (type === 'function') {
              const color = item.colorHex || palette.function;
              const label = item.label || item.id || '';
              const expression = normalizeExpression(item.expression || '');
              const evaluator = safeFunctionFromExpression(
                expression,
                settings.degreeMode === true,
              );
              if (!evaluator) {
                continue;
              }
              const left = numberOrFallback((settings.viewport || {}).left, -8);
              const right = numberOrFallback((settings.viewport || {}).right, 8);
              const graph = board.create(
                'functiongraph',
                [
                  function (x) {
                    return evaluator(x);
                  },
                  left,
                  right,
                ],
                {
                  strokeColor: color,
                  strokeWidth: 2.2,
                  name: label,
                  withLabel: Boolean(label),
                },
              );
              renderedElements.push(graph);
              functionItems.push(graph);
              hasRenderable = true;
              continue;
            }
            if (type === 'line' || type === 'scatter') {
              const color = item.colorHex || (type === 'line' ? palette.line : palette.scatter);
              const xValues = Array.isArray(item.xValues) ? item.xValues : [];
              const yValues = Array.isArray(item.yValues) ? item.yValues : [];
              const points = xValues
                .map((x, index) => [numberOrFallback(x, 0), numberOrFallback(yValues[index], 0)])
                .filter((pair) => Number.isFinite(pair[0]) && Number.isFinite(pair[1]));
              if (points.length < 2) continue;
              if (type === 'scatter') {
                const pointElements = points.map((point, index) => {
                  return board.create(
                    'point',
                    point,
                    {
                      name:
                        (item.label || '') + (points.length > 1 ? '-' + String(index + 1) : ''),
                      withLabel: false,
                      fixed: true,
                      size: 3,
                      color: color,
                      fillColor: color,
                      strokeColor: color,
                    },
                  );
                });
                renderedElements.push(...pointElements);
                for (const e of pointElements) {
                  functionItems.push(e);
                }
                hasRenderable = true;
              } else {
                const curve = board.create(
                  'curve',
                  [
                    points.map((point) => point[0]),
                    points.map((point) => point[1]),
                  ],
                  {
                    strokeColor: color,
                    strokeWidth: 2,
                    fillColor: 'none',
                    fixed: true,
                  },
                );
                renderedElements.push(curve);
                functionItems.push(curve);
                hasRenderable = true;
              }
            }
          }
          if (!hasRenderable) {
            setStatus('그래프 항목이 없어 표시할 수 없습니다.');
          } else {
            setStatus(functionItems.length ? '슬라이더/식 변경을 반영했습니다.' : '그래프를 렌더링할 수 없습니다.');
          }
          board.update();
          applyAxesStyle();
          board.update();
        }

        function applyGraphPayload(payloadJson, isInitial) {
          let parsedPayload = payloadJson;
          try {
            if (typeof payloadJson === 'string') {
              parsedPayload = JSON.parse(payloadJson);
            }
            currentPayload = parsedPayload || {};
            if (!currentPayload || typeof currentPayload !== 'object') {
              throw new Error('Invalid payload');
            }
          } catch (_) {
            setStatus('그래프 데이터 파싱 실패');
            return;
          }

          const parameters = (currentPayload.settings && currentPayload.settings.parameters) || [];
          parameterValues = buildFormulaMap();
          renderControls(parameters);

          if (!window.JXG || typeof window.JXG.JSXGraph?.initBoard !== 'function') {
            setRenderMode(true);
            drawFallback(currentPayload);
            return;
          }
          if (!board || isInitial) {
            if (board) {
              board.off();
              board = null;
            }
            board = ensureBoard(currentPayload);
            if (!board) {
              return;
            }
            renderCurrentGraph();
            window.requestAnimationFrame(refreshBoardSize);
          } else {
            renderCurrentGraph();
          }
        }

        window.applyGraphPayload = function(payload) {
          applyGraphPayload(payload, false);
        };

        function applyInitialPayload() {
          if (!initialViewport) {
            applyGraphPayload(initialPayload, true);
          }
        }

        function startLibraryLoadGuard() {
          setStatus('JSXGraph 로딩 중...');
          libraryLoadAttempted = true;
          let waitCount = 0;
          const maxWait = 2000;

          const fallbackOnce = () => {
            if (useFallback) return;
            setRenderMode(true);
            drawFallback(initialPayload);
            setStatus('JSXGraph 라이브러리를 불러오지 못해 미리보기 모드로 전환했습니다.');
            libraryLoadCompleted = true;
          };

          const loop = () => {
            if (window.JXG && typeof window.JXG.JSXGraph?.initBoard === 'function') {
              libraryLoadCompleted = true;
              applyInitialPayload();
              return;
            }
            if (waitCount > 30 || libraryLoadCompleted) {
              fallbackOnce();
              return;
            }
            waitCount += 1;
            setTimeout(loop, 80);
          };

          loop();
        }

        function bindLibraryLoadEvents() {
          const script = document.getElementById('jsxgraph-script');
          if (!script) {
            fallbackOnce();
            return;
          }
          if (script.readyState === 'complete' || script.readyState === 'loaded') {
            if (window.JXG && typeof window.JXG.JSXGraph?.initBoard === 'function') {
              libraryLoadCompleted = true;
              applyInitialPayload();
              return;
            }
          }
          if (libraryLoadAttempted || libraryLoadCompleted) return;
          startLibraryLoadGuard();
        }

        if (window.JXG && typeof window.JXG.JSXGraph?.initBoard === 'function') {
          applyInitialPayload();
        } else {
          bindLibraryLoadEvents();
          const script = document.getElementById('jsxgraph-script');
          if (script) {
            script.addEventListener('load', () => {
              if (window.JXG && typeof window.JXG.JSXGraph?.initBoard === 'function') {
                libraryLoadCompleted = true;
                setStatus('JSXGraph 로딩 완료');
                applyInitialPayload();
              } else {
                setRenderMode(true);
                drawFallback(initialPayload);
                setStatus('JSXGraph 초기화에 실패해 미리보기 모드로 전환했습니다.');
              }
            });
            script.addEventListener('error', () => {
              setRenderMode(true);
              drawFallback(initialPayload);
              setStatus('JSXGraph CDN 로딩 실패: 미리보기 모드로 전환했습니다.');
            });
          } else {
            bindLibraryLoadEvents();
          }
        }

        zoomInBtn?.addEventListener('click', () => {
          if (!board || !board.zoomIn) return;
          board.zoomIn();
        });
        zoomOutBtn?.addEventListener('click', () => {
          if (!board || !board.zoomOut) return;
          board.zoomOut();
        });
        resetBtn?.addEventListener('click', () => {
          if (!board || !initialViewport) return;
          board.setBoundingBox(initialViewport, false);
          setStatus('초기 뷰로 되돌렸습니다.');
        });

        window.addEventListener('message', (event) => {
          if (!event || !event.data) return;
          applyGraphPayload(event.data, false);
        });
      })();
    </script>
  </body>
</html>
'''
      .replaceAll(r'__AIFLOW_GRAPH_PAYLOAD__', escapedPayload)
      .replaceAll(
        r'__AIFLOW_GRAPH_CONTROLS_DISPLAY__',
        showParameterControls ? 'flex' : 'none',
      )
      .replaceAll(
        r'__AIFLOW_GRAPH_BODY_CLASS__',
        directManipulationMode ? 'direct-drawing' : '',
      )
      .replaceAll(
        r'__AIFLOW_GRAPH_SHOW_NAVIGATION__',
        directManipulationMode ? 'false' : 'true',
      );
}
