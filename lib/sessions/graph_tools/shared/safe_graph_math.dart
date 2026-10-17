/// Arithmetic-only evaluator shared by web/native graph documents.
/// Author input is parsed into bounded nodes, never evaluated as JavaScript.
const safeGraphMathJavascript = r'''
function compileGraphMath(source, parameterNames, degreeMode, variableName = 'x') {
  if (typeof source !== 'string' || source.length > 1000) return null;
  const allowed = new Set([variableName, 'pi', 'e', ...parameterNames]);
  const radians = value => degreeMode ? value * Math.PI / 180 : value;
  const functions = Object.freeze({
    abs: Math.abs, max: Math.max, min: Math.min, sqrt: Math.sqrt,
    pow: Math.pow, exp: Math.exp, ln: Math.log, log: Math.log10,
    sin: value => Math.sin(radians(value)), cos: value => Math.cos(radians(value)),
    tan: value => Math.tan(radians(value)), ceil: Math.ceil, floor: Math.floor, round: Math.round
  });
  const tokens = [];
  let offset = 0;
  while (offset < source.length) {
    if (/\s/.test(source[offset])) { offset++; continue; }
    const rest = source.slice(offset);
    const number = /^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/.exec(rest);
    const name = /^[A-Za-z][A-Za-z0-9_]*/.exec(rest);
    if (number) { tokens.push({number: Number(number[0])}); offset += number[0].length; }
    else if (name) { tokens.push({name: name[0]}); offset += name[0].length; }
    else if (rest.startsWith('**')) { tokens.push('^'); offset += 2; }
    else if ('+-*/^(),'.includes(source[offset])) tokens.push(source[offset++]);
    else return null;
    if (tokens.length > 160) return null;
  }
  let position = 0, depth = 0;
  const take = value => tokens[position] === value ? (position++, true) : false;
  const expression = () => sum();
  function atom() {
    if (++depth > 32) throw Error('Expression nesting limit');
    let node;
    if (take('(')) {
      node = expression();
      if (!take(')')) throw Error('Unclosed arithmetic');
    } else {
      const token = tokens[position++];
      if (token && typeof token.number === 'number' && Number.isFinite(token.number)) node = ['number', token.number];
      else if (token && token.name) {
        if (take('(')) {
          if (!Object.hasOwn(functions, token.name)) throw Error('Unknown function');
          const args = [expression()];
          while (take(',')) { if (args.length >= 8) throw Error('Argument limit'); args.push(expression()); }
          if (!take(')')) throw Error('Unclosed call');
          node = ['call', token.name, args];
        } else {
          if (!allowed.has(token.name)) throw Error('Unknown variable');
          node = ['variable', token.name];
        }
      } else throw Error('Expected arithmetic');
    }
    depth--;
    return node;
  }
  function power() {
    const left = atom();
    return take('^') ? ['^', left, unary()] : left;
  }
  function unary() {
    if (++depth > 32) throw Error('Expression nesting limit');
    const result = take('+') ? unary() : take('-') ? ['negate', unary()] : power();
    depth--;
    return result;
  }
  function product() {
    let result = unary();
    while (tokens[position] === '*' || tokens[position] === '/') {
      const op = tokens[position++]; result = [op, result, unary()];
    }
    return result;
  }
  function sum() {
    let result = product();
    while (tokens[position] === '+' || tokens[position] === '-') {
      const op = tokens[position++]; result = [op, result, product()];
    }
    return result;
  }
  function value(node, x, parameters) {
    switch (node[0]) {
      case 'number': return node[1];
      case 'variable': return node[1] === variableName ? x : node[1] === 'pi' ? Math.PI : node[1] === 'e' ? Math.E : Number(parameters[node[1]]);
      case 'call': return functions[node[1]](...node[2].map(arg => value(arg, x, parameters)));
      case 'negate': return -value(node[1], x, parameters);
      case '+': return value(node[1], x, parameters) + value(node[2], x, parameters);
      case '-': return value(node[1], x, parameters) - value(node[2], x, parameters);
      case '*': return value(node[1], x, parameters) * value(node[2], x, parameters);
      case '/': return value(node[1], x, parameters) / value(node[2], x, parameters);
      case '^': return value(node[1], x, parameters) ** value(node[2], x, parameters);
      default: return NaN;
    }
  }
  try {
    const root = expression();
    if (position !== tokens.length) return null;
    return (x, parameters = Object.create(null)) => {
      const result = value(root, Number(x), parameters);
      return Number.isFinite(result) ? result : NaN;
    };
  } catch (_) { return null; }
}
''';
