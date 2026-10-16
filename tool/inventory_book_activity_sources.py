"""Non-executing HTML evidence inventory. Signals are NOT behavior/parity proof."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re


def digest(value: str) -> str:
    return hashlib.sha256(value.encode('utf-8')).hexdigest()


class AssetParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.controls, self.external_scripts, self.inline_events = [], [], []
        self.svg_tags = Counter()
        self.scripts, self._script = [], None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('input', 'select', 'button', 'textarea'):
            self.controls.append({'tag': tag, **{key: attrs[key] for key in
                ('id', 'type', 'name', 'min', 'max', 'step', 'value') if key in attrs}})
        for key, value in attrs.items():
            if key.startswith('on'):
                self.inline_events.append({'tag': tag, 'id': attrs.get('id'),
                                           'event': key, 'body_sha256': digest(value or '')})
        if tag in ('svg', 'line', 'path', 'circle', 'polygon', 'polyline', 'rect', 'text'):
            self.svg_tags[tag] += 1
        if tag == 'script':
            if attrs.get('src'):
                self.external_scripts.append(attrs['src'])
                self._script = None
            else:
                self._script = []

    def handle_endtag(self, tag):
        if tag == 'script' and self._script is not None:
            self.scripts.append(''.join(self._script))
            self._script = None

    def handle_data(self, data):
        if self._script is not None:
            self._script.append(data)


def inspect_asset(path: Path, root: Path) -> dict:
    raw = path.read_bytes()
    source = raw.decode('utf-8-sig')
    parser = AssetParser()
    parser.feed(source)
    script = '\n'.join(parser.scripts)
    relative = path.relative_to(root).as_posix()
    # Evidence extraction only. Regex matches can include comments/dead code.
    signals = {
        'randomness': bool(re.search(r'Math\.random|getRandomValues', script)),
        'pointer_events': bool(re.search(r'pointerdown|pointermove|touchmove|mousedown|mousemove', script)),
        'timed_callbacks': bool(re.search(r'setTimeout|setInterval|requestAnimationFrame', script)),
        'reduced_motion_reference': 'prefers-reduced-motion' in source,
        'network_call_reference': bool(re.search(r'\bfetch\s*\(|XMLHttpRequest|WebSocket', script)),
    }
    return {'asset_id': 'html-' + digest(relative)[:16], 'path': relative,
            'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
            'script_sha256': digest(script), 'inline_script_count': len(parser.scripts),
            'external_scripts': parser.external_scripts, 'controls': parser.controls,
            'inline_event_attributes': parser.inline_events,
            'svg_tag_counts': dict(parser.svg_tags), 'static_signals': signals,
            'event_names': sorted(set(re.findall(r'addEventListener\s*\(\s*[\'"]([^\'"]+)', script))),
            'declared_function_names': sorted(set(re.findall(r'\bfunction\s+([A-Za-z_$][\w$]*)\s*\(', script))),
            'manuscript_mapping': 'unresolved_until_explicit_source_index',
            'status': 'source_review_required_not_ported'}


def inventory(root: Path) -> dict:
    assets = [inspect_asset(path, root) for path in sorted(root.rglob('*.html'))]
    identities = [asset['asset_id'] for asset in assets]
    if len(identities) != len(set(identities)):
        raise ValueError('Asset identity collision')
    return {'schema_version': 1, 'source_root': str(root),
            'method': 'HTMLParser metadata and non-executing static signals; no behavior/parity assertions',
            'asset_count': len(assets), 'distinct_script_hashes': len({a['script_sha256'] for a in assets}),
            'signal_counts': {key: sum(a['static_signals'][key] for a in assets)
                              for key in (assets[0]['static_signals'] if assets else ())},
            'assets': assets}


if __name__ == '__main__':
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('source_root', type=Path)
    args = cli.parse_args()
    print(json.dumps(inventory(args.source_root.resolve(strict=True)), ensure_ascii=True, indent=2))
