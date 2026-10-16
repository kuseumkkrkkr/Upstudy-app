// Execute trusted generated renderer code with in-memory DOM/board doubles.
// This is not browser automation and never evaluates author-supplied JS.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(process.argv[2], 'utf8');
const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];

function run(fallback) {
  const nodes = new Map(), created = [], arcs = [];
  const ctx = new Proxy({arc: (...args) => arcs.push(args)}, {
    get: (target, key) => target[key] || (() => {}),
  });
  function element() {
    return {style: {}, children: [], listeners: {}, clientWidth: 320, clientHeight: 220,
      appendChild(child) { this.children.push(child); },
      addEventListener(name, fn) { this.listeners[name] = fn; },
      setAttribute() {}, getContext() { return ctx; }};
  }
  const document = {body: {classList: {contains: () => false}},
    getElementById(id) { if (!nodes.has(id)) nodes.set(id, element()); return nodes.get(id); },
    createElement: element};
  const board = {attr: {pan: {}, zoom: {}}, grids: [], defaultAxes: {},
    renderer: {container: {style: {}}},
    create(type, values, attributes) { const value = {type, values, attributes}; created.push(value); return value; },
    removeObject() {}, fullUpdate() {}, update() {}, on() {}, resizeContainer() {},
    getBoundingBox: () => [-8, 8, 8, -8]};
  const JXG = fallback ? undefined : {JSXGraph: {initBoard: () => board}};
  const window = {JXG, devicePixelRatio: 1, requestAnimationFrame: fn => fn(), addEventListener() {}};
  window.parent = window;
  vm.runInNewContext(script, {window, document, JXG, console,
    setTimeout() {}, clearTimeout() {}}, {timeout: 3000});
  if (fallback) nodes.get('jsxgraph-script').listeners.error();
  const readout = nodes.get('observationReadout');
  const before = readout.textContent;
  const curvesBefore = created.filter(e => e.type === 'functiongraph')
    .map(e => [-2, -1, 0, 1, 2].map(e.values[0]));
  const beforeArcs = arcs.slice();
  const range = nodes.get('controls').children[0].children.find(child => child.type === 'range');
  range.value = '.5'; range.listeners.input();
  const after = readout.textContent;
  assert.match(before, /x=-1, y=2/);
  assert.match(after, /x=0.5, y=-1.375/);
  assert.match(after, /y=1.25/);
  assert.match(after, /y=-3/);
  if (!fallback) {
    assert.ok(created.filter(e => e.type === 'functiongraph').every(e => e.attributes.withLabel === false));
    const points = created.filter(e => e.type === 'point').slice(-3).map(e => [...e.values]);
    assert.deepEqual(points, [[.5, -1.375], [.5, 1.25], [.5, -3]]);
    const curvesAfter = created.filter(e => e.type === 'functiongraph').slice(-3)
      .map(e => [-2, -1, 0, 1, 2].map(e.values[0]));
    assert.deepEqual(curvesAfter, curvesBefore);
  } else {
    assert.equal(beforeArcs.length, 3);
    assert.equal(arcs.length, 6);
    assert.notEqual(arcs[0][0], arcs[3][0]);
    assert.notEqual(arcs[0][1], arcs[3][1]);
  }
  return {fallback, before, after};
}
console.log(JSON.stringify([run(false), run(true)]));
