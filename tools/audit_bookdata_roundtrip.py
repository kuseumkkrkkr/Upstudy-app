"""Local compatibility audit only: never produces a publication bundle/approval."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from api.textbook_import import parse_import
from tools.build_public_textbooks import prepare


def audit(root):
    records, runtime = [], []
    for path in sorted(root.rglob('*BookData*.json')):
        source = path.read_text(encoding='utf-8-sig')
        digest = hashlib.sha256(source.replace('\r\n', '\n').encode()).hexdigest()
        record = {'path': path.relative_to(root).as_posix(), 'source_sha256': digest}
        try:
            entry = prepare(source)
            parsed, _ = parse_import(entry['source'], entry['sha256'])
            restored = json.loads(json.dumps(parsed, ensure_ascii=False))
            annotations = entry['source_metadata']['annotations']
            restored.update(annotations['book'])
            for chapter, metadata in zip(restored['chapters'], annotations['chapters']):
                chapter.update(metadata)
            original = json.loads(source)
            if 'standard_code' in original:
                if 'standard_codes' not in original:
                    restored.pop('standard_codes')
                restored['standard_code'] = original['standard_code']
            if 'schema_migration' in annotations:
                restored.pop('schema_version')
            if restored != original:
                raise ValueError('Author content failed exact reconstruction')
            if path.read_text(encoding='utf-8-sig') != source:
                raise ValueError('Source changed during audit; rerun')
            record.update(status='roundtrip_pass', runtime_sha256=entry['sha256'])
            runtime.append({'path': record['path'], 'book': parsed})
        except (ValueError, TypeError, KeyError, RecursionError) as error:
            record.update(status='blocked', error=str(error))
        records.append(record)
    return {'purpose': 'private compatibility audit; not content or rights approval',
            'files': len(records), 'passed': len(runtime),
            'blocked': len(records) - len(runtime), 'records': records}, runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_root', type=Path)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--private-fixture', type=Path)
    args = parser.parse_args()
    expected = Path('D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix').resolve()
    if Path.cwd().resolve() != expected:
        raise SystemExit('Run from the guarded D: hotfix checkout')
    branch = subprocess.check_output(['git', '-c', f'safe.directory={expected.as_posix()}',
        'branch', '--show-current'], text=True).strip()
    if branch != 'hotfix':
        raise SystemExit('Only hotfix is allowed')
    for output in (args.report, args.private_fixture):
        if output is not None and not output.resolve().is_relative_to(expected / 'build/temp'):
            raise SystemExit('Private audit output must stay in build/temp')
    report, fixture = audit(args.source_root)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    if args.private_fixture:
        args.private_fixture.write_text(json.dumps(fixture, ensure_ascii=False), encoding='utf-8')
    print(json.dumps({key: report[key] for key in ('files', 'passed', 'blocked')}))
    return 1 if report['blocked'] or not report['files'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
