from tools.prepare_product_api_cutover import FILES, SOURCE_TABLES, bundle


def test_cutover_is_one_backed_up_transaction_with_disposable_smoke():
    sql = bundle(rollback=False)
    assert sql.startswith("begin;\n")
    assert sql.endswith("commit;\n")
    assert sum(line.strip() == "begin;" for line in sql.splitlines()) == 1
    assert sum(line.strip() == "commit;" for line in sql.splitlines()) == 1
    assert "savepoint api_cutover_smoke;" in sql
    assert "rollback to savepoint api_cutover_smoke;" in sql
    assert sql.index("rollback to savepoint api_cutover_smoke;") < sql.index("notify pgrst")
    for name in FILES:
        assert f"-- {name}\n" in sql
    for table in SOURCE_TABLES:
        assert f"aiflow_api_cutover_20261012.{table} as table public.{table}" in sql
    assert "from public,anon,authenticated,service_role" in sql
    assert "set value=(value::jsonb-'answers')::text" in sql


def test_preflight_only_changes_final_transaction_outcome():
    apply = bundle(rollback=False)
    preflight = bundle(rollback=True)
    assert preflight.endswith("rollback;\n")
    assert preflight.removesuffix("rollback;\n") == apply.removesuffix("commit;\n")
