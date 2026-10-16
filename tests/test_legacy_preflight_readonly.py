"""Static safety framing only: not a PostgreSQL execution/FK verification claim."""
from pathlib import Path
import re

import pytest


@pytest.mark.parametrize('name', [
    'legacy_admin_catalog_readonly.sql', 'legacy_student_records_readonly.sql'])
def test_preflight_is_rollback_only_without_mutating_statements(name):
    sql = (Path(__file__).parents[1] / 'deploy/vercel' / name).read_text(encoding='utf-8')
    code = re.sub(r'--[^\n]*', '', sql)
    code = re.sub(r"'(?:''|[^'])*'", "''", code).lower().strip()
    assert code.startswith('begin transaction isolation level repeatable read read only;')
    assert code.endswith('rollback;')
    assert 'set local statement_timeout' in code
    assert 'set local lock_timeout' in code
    assert not re.search(r'\b(insert|update|delete|truncate|drop|alter|create|grant|revoke|call|copy|execute|commit|vacuum|reindex|refresh)\b', code)
    assert 'pg_constraint' in code and 'pg_trigger' in code
