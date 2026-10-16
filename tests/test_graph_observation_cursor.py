"""Execute the shared renderer's actual observer helper, not a replica."""
import json
from pathlib import Path
import subprocess


def test_cursor_moves_without_changing_curve_coordinates_or_expressions():
    root = Path(__file__).resolve().parents[1]
    builder = (root / 'lib/sessions/graph_tools/shared/jsx_graph_html_builder.dart').read_text(encoding='utf-8')
    math = (root / 'lib/sessions/graph_tools/shared/safe_graph_math.dart').read_text(encoding='utf-8').split("r'''", 1)[1].rsplit("'''", 1)[0]
    helper = builder.split('        function observationPoint(', 1)[1].split('        function updateObservationReadout(', 1)[0]
    source = math + '\nfunction observationPoint(' + helper
    probe = r'''
let parameterValues = {observed_x: -1};
const settings = {parameters: [{id:'observed_x',role:'observationX',min:-2,max:2}]};
const f = compileGraphMath('x^3-3*x', [], false);
const evaluator = x => f(x, parameterValues);
const curveBefore = [-2,-1,0,1,2].map(evaluator);
const before = observationPoint(settings,evaluator);
parameterValues.observed_x = .5;
const after = observationPoint(settings,evaluator);
const curveAfter = [-2,-1,0,1,2].map(evaluator);
parameterValues.observed_x = 3;
const outOfRange = observationPoint(settings,evaluator);
parameterValues.observed_x = 0;
const undefinedPoint = observationPoint(settings,x=>NaN);
const duplicate = observationPoint({parameters:[...settings.parameters,...settings.parameters]},evaluator);
console.log(JSON.stringify({before,after,curveBefore,curveAfter,outOfRange,undefinedPoint,duplicate}));
'''
    result = subprocess.run(['node', '-e', source + probe], capture_output=True, text=True, check=True, timeout=15)
    data = json.loads(result.stdout)
    assert data['before'] == {'x': -1, 'y': 2}
    assert data['after'] == {'x': .5, 'y': -1.375}
    assert data['curveBefore'] == data['curveAfter'] == [-2, 2, 0, -2, 2]
    assert data['outOfRange'] is data['undefinedPoint'] is data['duplicate'] is None
    # Both rendering paths use the same helper, and both platform embeds use
    # this shared builder; actual native device execution is a separate check.
    assert builder.count('const point = observationPoint(settings, evaluator);') == 2
    assert '.filter(p => p.role !== \'observationX\')' in builder
    assert 'new Function' not in builder and 'eval(' not in builder
    for platform in ('web', 'native'):
        embed = (root / f'lib/sessions/graph_tools/ui/widgets/jsx_graph_embed_{platform}.dart').read_text(encoding='utf-8')
        assert 'buildAiFlowGraphHtml(' in embed
