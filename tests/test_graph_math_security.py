"""Execute the actual embedded arithmetic parser without a browser or eval inputs."""
import json
from pathlib import Path
import subprocess


def test_embedded_math_evaluates_sliders_and_rejects_javascript():
    root = Path(__file__).resolve().parents[1]
    dart = (root / 'lib/sessions/graph_tools/shared/safe_graph_math.dart').read_text(encoding='utf-8')
    source = dart.split("r'''", 1)[1].rsplit("'''", 1)[0]
    probe = r'''
const f = compileGraphMath('x*x/(4*p)', ['p'], false);
const degree = compileGraphMath('sin(x)', [], true);
const power = compileGraphMath('-x**2', [], false);
const unsafe = ['window.alert(1)', 'x.constructor', '(()=>1)()', '[x][0]', 'this', 'parent', 'x=2', '1;2', 'sin.constructor(1)', 'x++'];
console.log(JSON.stringify({values:[f(4,{p:2}), f(4,{p:1}),degree(90),power(2)], rejected:unsafe.map(e=>compileGraphMath(e,[],false)===null)}));
'''
    result = subprocess.run(['node', '-e', source + probe], capture_output=True, text=True, check=True, timeout=15)
    parsed = json.loads(result.stdout)
    assert parsed['values'] == [2, 4, 1, -4]
    assert all(parsed['rejected'])
    builder = (root / 'lib/sessions/graph_tools/shared/jsx_graph_html_builder.dart').read_text(encoding='utf-8')
    assert 'new Function' not in builder and 'eval(' not in builder
    web = (root / 'lib/sessions/graph_tools/ui/widgets/jsx_graph_embed_web.dart').read_text(encoding='utf-8')
    assert "setAttribute('sandbox', 'allow-scripts')" in web
    assert "event.source != _iframe.contentWindow" in web
