"""Audit all author BookData; only write a release bundle if EVERY file passes.

Explicit non-rendered author annotations remain in source_metadata. Runtime
content is validated unchanged; unsupported graphs/quiz blocks are never dropped.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path

from api.textbook_import import _unique_object, _reject_constant, parse_import

ROOT_ANNOTATIONS = {'metadata', 'standard_coverage', 'grade_semester_status',
    'teacher_review_status', 'units'}
CHAPTER_ANNOTATIONS = {'unit', 'title_code', 'unit_name', 'unitTitle', 'candidate_standard_codes'}


def migrate_observation_sliders(book):
    """Separate explicitly labelled observation x from the curve coordinate.

    Expressions are untouched. Each original parameter is recorded by its exact
    location for reversible audit; ambiguous x parameters still fail validation.
    """
    migrations = []
    for ci, chapter in enumerate(book.get('chapters', [])):
        graphs = []
        for si, section in enumerate(chapter.get('sections', [])):
            if 'graph' in section:
                graphs.append((['chapters', ci, 'sections', si, 'graph'], section['graph']))
        for pi, page in enumerate(chapter.get('pages', [])):
            for bi, block in enumerate(page.get('blocks', [])):
                if 'graph' in block:
                    graphs.append((['chapters', ci, 'pages', pi, 'blocks', bi, 'graph'], block['graph']))
        for path, graph in graphs:
            parameters = graph.get('settings', {}).get('parameters', [])
            for index, parameter in enumerate(parameters):
                if (parameter.get('id') != 'x' or parameter.get('label') != '관찰 위치 x'
                        or 'role' in parameter):
                    continue
                if any(p.get('id') == 'observed_x' or p.get('role') == 'observationX' for p in parameters):
                    raise ValueError('graph: observation migration conflicts with existing parameter')
                migrations.append({'path': path + ['settings', 'parameters', index],
                                   'original': copy.deepcopy(parameter)})
                parameter['id'] = 'observed_x'
                parameter['role'] = 'observationX'
    return migrations


def prepare(source):
    original = json.loads(source, object_pairs_hook=_unique_object, parse_constant=_reject_constant)
    book = copy.deepcopy(original)
    annotations = {'book': {}, 'chapters': []}
    migrations = migrate_observation_sliders(book)
    if migrations:
        annotations['graph_parameter_migrations'] = migrations
    # Older author exports omitted the version despite explicit registered V2
    # activities. Upgrade only a missing declaration; never override explicit V1.
    if 'schema_version' not in book and any(
            block.get('type') == 'activity'
            for chapter in book.get('chapters', [])
            for page in chapter.get('pages', []) for block in page.get('blocks', [])):
        book['schema_version'] = 2
        annotations['schema_migration'] = {'from': 'omitted', 'to': 2}
    for key in ROOT_ANNOTATIONS:
        if key in book:
            annotations['book'][key] = book.pop(key)
    if 'standard_code' in book:
        value = book.pop('standard_code')
        if not isinstance(value, str) or ('standard_codes' in book and book['standard_codes'] != [value]):
            raise ValueError('Conflicting or invalid standard_code')
        book['standard_codes'] = [value]
    for chapter in book.get('chapters', []):
        annotations['chapters'].append({key: chapter.pop(key)
            for key in sorted(CHAPTER_ANNOTATIONS) if key in chapter})
    runtime = json.dumps(book, ensure_ascii=False, separators=(',', ':'))
    digest = hashlib.sha256(runtime.encode()).hexdigest()
    parse_import(runtime, digest)
    return {'source': runtime, 'sha256': digest, 'source_metadata': {
        'original_sha256': hashlib.sha256(source.replace('\r\n', '\n').encode()).hexdigest(),
        'annotations': annotations}}


def approved_files(source_root, manifest):
    """Freeze explicit reviewed inputs; sibling drafts can never enter a release."""
    if set(manifest) != {'version', 'files'} or manifest['version'] != 1:
        raise ValueError('Invalid publication approval manifest')
    if not isinstance(manifest['files'], list) or not 1 <= len(manifest['files']) <= 1000:
        raise ValueError('Approval manifest requires 1..1000 explicit files')
    root = source_root.resolve(); selected = {}; seen = set()
    for item in manifest['files']:
        if set(item) != {'path', 'sha256', 'publication_approved', 'rights_status', 'teacher_review_status', 'math_review_status', 'curriculum_review_status'}:
            raise ValueError('Approval entry fields must be explicit')
        if (item['publication_approved'] is not True or item['rights_status'] != 'cleared'
                or item['teacher_review_status'] != 'approved' or item['math_review_status'] != 'approved'
                or item['curriculum_review_status'] != 'approved'):
            raise ValueError('Publication/rights/teacher/math/curriculum approval is incomplete')
        path = (root / item['path']).resolve()
        if not path.is_relative_to(root) or path == root or path in seen or not path.is_file():
            raise ValueError('Approval path is missing, repeated or outside the source root')
        seen.add(path)
        source = path.read_text(encoding='utf-8-sig')
        digest = hashlib.sha256(source.replace('\r\n', '\n').encode()).hexdigest()
        if digest != item['sha256']:
            raise ValueError('Approved source changed: ' + item['path'])
        selected[path] = source
    return selected


def build(source_root, manifest=None):
    source_root = source_root.resolve()
    selected = approved_files(source_root, manifest) if manifest is not None else {
        path: path.read_text(encoding='utf-8-sig') for path in sorted(source_root.rglob('*BookData*.json'))}
    entries = {}; errors = []; files = sorted(selected)
    for path in files:
        try:
            entry = prepare(selected[path])
            entry['source_metadata']['file'] = str(path.relative_to(source_root))
            if manifest is not None:
                approval = next(item for item in manifest['files']
                                if (source_root / item['path']).resolve() == path)
                entry['source_metadata']['approval'] = {
                    key: approval[key] for key in ('sha256', 'publication_approved',
                        'rights_status', 'teacher_review_status', 'math_review_status',
                        'curriculum_review_status')}
            if entry['sha256'] in entries:
                raise ValueError('Duplicate runtime content: choose one explicit publication source')
            entries[entry['sha256']] = entry
        except (ValueError, TypeError, KeyError, RecursionError) as error:
            errors.append({'file': str(path.relative_to(source_root)), 'error': str(error)})
    return {'files': len(files), 'valid': len(entries), 'errors': errors}, list(entries.values())


def main():
    expected = Path('D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix')
    if Path.cwd().resolve() != expected.resolve():
        raise SystemExit('Run from the guarded D: hotfix checkout only')
    branch = subprocess.check_output(['git', '-c', f'safe.directory={expected.as_posix()}',
        'branch', '--show-current'], text=True).strip()
    if branch != 'hotfix':
        raise SystemExit('Only hotfix is allowed')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_root', type=Path)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--approval-manifest', type=Path)
    args = parser.parse_args()
    for output in (args.report, args.output):
        if output is not None and not output.resolve().is_relative_to(expected.resolve()):
            raise SystemExit('All reports and release outputs must stay in the D: hotfix checkout')
    if args.output and not args.approval_manifest:
        raise SystemExit('A release requires an explicit source/hash/approval manifest; folder audit alone cannot publish')
    manifest = (json.loads(args.approval_manifest.read_text(encoding='utf-8'))
        if args.approval_manifest else None)
    report, entries = build(args.source_root, manifest)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'files': report['files'], 'valid': report['valid'], 'blocked': len(report['errors'])}))
    if not report['files'] or report['errors']:
        raise SystemExit(1)
    if args.output:
        if args.output.exists():
            raise SystemExit('Refusing to overwrite an existing release bundle')
        args.output.write_text(json.dumps({'version': 1, 'books': entries}, ensure_ascii=False), encoding='utf-8')


if __name__ == '__main__':
    main()
