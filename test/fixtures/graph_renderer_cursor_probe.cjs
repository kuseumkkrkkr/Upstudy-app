// Execute trusted generated renderer code with in-memory DOM/board doubles.
// This is not browser automation and never evaluates author-supplied JavaScript.
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
  if (process.argv[3] === 'scatter') {
    if (fallback) {
      assert.equal(arcs.length, 2, 'two singleton scatter items must render');
    } else {
      assert.deepEqual(created.filter(e => e.type === 'point').map(e => [...e.values]),
        [[-2, 3], [3, -2]]);
      assert.equal(created.filter(e => e.type === 'curve').length, 0,
        'a single point is not a line segment');
    }
    return {fallback, singletonScatter: 2};
  }
}

console.log(JSON.stringify([run(false), run(true)]));
