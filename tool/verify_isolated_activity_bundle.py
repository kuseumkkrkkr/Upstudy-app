"""Verify a static feature bundle's exact committed application-source closure."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

root = Path.cwd().resolve()
expected = {
    'tool/book_activity_isolated_preview.dart',
    'lib/shared/data/models/book_activity.dart',
    'lib/shared/data/models/book_discrete_experiment.dart',
    'lib/shared/data/models/book_statistics_estimator.dart',
    'lib/sessions/textbook/ui/widgets/book_activity_view.dart',
    'lib/sessions/textbook/ui/widgets/book_discrete_experiment_view.dart',
    'lib/sessions/textbook/ui/widgets/book_statistics_estimator_view.dart',
}
assert root == Path('D:/AIFlow-Workspace/Projects/Aiflow/Upstudy-hotfix'), root
depfile = Path(sys.argv[1]).resolve()
assert depfile.is_relative_to(root / '.dart_tool/flutter_build')
raw = depfile.read_text(encoding='utf-8').replace('\\\\', '/')
prefix = root.as_posix() + '/'
found = set(re.findall(re.escape(prefix) + r'((?:lib|tool)/[^\s]+?\.dart)', raw))
assert found == expected, {'unexpected': sorted(found - expected), 'missing': sorted(expected - found)}
def git(*args):
    return subprocess.check_output(['git', '-c', f'safe.directory={root.as_posix()}', *args], text=True).strip()
assert git('branch', '--show-current') == 'hotfix'
git('diff', '--exit-code', 'HEAD', '--', *sorted(expected))
sources = {p: git('rev-parse', 'HEAD:' + p) for p in sorted(expected)}
bundle = root / 'build/native-statistics-preview/main.dart.js'
body = bundle.read_bytes()
assert all(marker not in body for marker in [b'synthetic-local-reader-only', b'BOOK_QA_JSON', b'aybqetiydxafeuzudltb', b'ekogkwhvyqwdxibjfnko'])
print(json.dumps({'head':git('rev-parse','HEAD'), 'application_sources':sources,
    'bytes':len(body), 'sha256':hashlib.sha256(body).hexdigest().upper(),
    'product_api_included':False, 'actual_bookwidget_included':False,
    'full_checkout_clean':not bool(git('status','--porcelain')),
    'project_dependency_config_has_unrelated_dirty_changes':bool(git('diff','--name-only','HEAD','--','pubspec.yaml','pubspec.lock'))}, indent=2))
