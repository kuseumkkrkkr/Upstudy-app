from pathlib import Path

from tool.inventory_book_activity_sources import inspect_asset, inventory


def test_inventory_does_not_execute_or_copy_script_body(tmp_path: Path):
    path = tmp_path / 'synthetic.html'
    path.write_text('''<input id="p" type="range" min="0" max="4" step="1">
        <button onclick="throw new Error('never execute')">Try</button>
        <svg><circle id="point"/></svg><script src="https://example.invalid/library.js"></script>
        <script>function draw(){throw 'do not execute';}
        p.addEventListener('input',draw); Math.random();</script>''', encoding='utf-8')
    result = inspect_asset(path, tmp_path)
    assert result['controls'][0]['id'] == 'p'
    assert result['event_names'] == ['input']
    assert result['declared_function_names'] == ['draw']
    assert result['static_signals']['randomness']
    assert result['inline_event_attributes'][0]['event'] == 'onclick'
    assert result['external_scripts'] == ['https://example.invalid/library.js']
    assert result['inline_script_count'] == 1
    assert result['status'] == 'source_review_required_not_ported'
    assert 'never execute' not in str(result) and 'do not execute' not in str(result)
    assert inventory(tmp_path)['asset_count'] == 1


def test_identity_is_path_stable_but_body_hash_changes(tmp_path: Path):
    path = tmp_path / 'synthetic.html'
    path.write_text('<script>function a(){}</script>', encoding='utf-8')
    before = inspect_asset(path, tmp_path)
    path.write_text('<script>function b(){}</script>', encoding='utf-8')
    after = inspect_asset(path, tmp_path)
    assert before['asset_id'] == after['asset_id']
    assert before['sha256'] != after['sha256']
