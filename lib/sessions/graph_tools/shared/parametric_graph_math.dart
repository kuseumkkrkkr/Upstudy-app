/// Bounded arithmetic-only curve sampler; shared by JSXGraph and canvas.
/// Sliders are runtime observations and never overwrite authored expressions.
const parametricGraphMathJavascript = r'''
function parametricGraph(item, settings) {
  const min = item.tMin, max = item.tMax;
  if (!Number.isFinite(min) || !Number.isFinite(max) || min >= max ||
      Math.abs(min) > 1e9 || Math.abs(max) > 1e9) return null;
  const parameters = settings.parameters || [];
  if (parameters.some(p => p.id === 't')) return null;
  const names = parameters.filter(p => p.role !== 'observationX').map(p => p.id);
  const xMath = compileGraphMath(normalizeExpression(item.xExpression), names, settings.degreeMode === true, 't');
  const yMath = compileGraphMath(normalizeExpression(item.yExpression), names, settings.degreeMode === true, 't');
  if (!xMath || !yMath) return null;
  const x = t => xMath(t, parameterValues), y = t => yMath(t, parameterValues);
  const segments = [];
  const view = settings.viewport || {left:-8, right:8, top:8, bottom:-8};
  const jumpX = 2 * (view.right - view.left), jumpY = 2 * (view.top - view.bottom);
  let segment = [];
  for (let i = 0; i <= 400; i++) {
    const t = min + (max - min) * i / 400, px = x(t), py = y(t);
    if (Number.isFinite(px) && Number.isFinite(py)) {
      // ponytail: bounded sampled plot, not a symbolic continuity proof. Never
      // bridge a jump larger than two view spans across a possible asymptote.
      const last = segment[segment.length - 1];
      if (last && (Math.abs(px-last[0]) > jumpX || Math.abs(py-last[1]) > jumpY)) {
        if (segment.length > 1) segments.push(segment);
        segment = [];
      }
      segment.push([px, py]);
    }
    else { if (segment.length > 1) segments.push(segment); segment = []; }
  }
  if (segment.length > 1) segments.push(segment);
  const slider = parameters.find(p => p.id === item.traceParameterId && p.role !== 'observationX');
  const t = slider && parameterValues[slider.id];
  let point = null;
  if (Number.isFinite(t) && t >= min && t <= max) {
    const px = x(t), py = y(t);
    if (Number.isFinite(px) && Number.isFinite(py)) {
      const h = Math.max(1e-7, Math.min((max - min) * 1e-5, 1e-3));
      const a = Math.max(min, t - h), b = Math.min(max, t + h);
      const dx = (x(b) - x(a)) / (b - a), dy = (y(b) - y(a)) / (b - a);
      const slope = Math.abs(dx) > 1e-8 ? dy / dx : NaN;
      point = {t, x: px, y: py, slope: Number.isFinite(slope) ? slope : null};
    }
  }
  return {segments, point};
}
''';
