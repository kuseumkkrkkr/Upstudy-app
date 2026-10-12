"""Compose the reviewed additive migrations as one backed-up transaction on D:."""
from pathlib import Path
import argparse
import hashlib
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    'supabase_ocr_queue.sql', 'supabase_ocr_grading.sql', 'supabase_rating.sql',
    'supabase_student_state.sql', 'supabase_arena_rankings.sql', 'supabase_ox_quiz.sql',
    'supabase_legacy_student_accounts.sql', 'supabase_arena_result_cleanup_cron.sql',
)
SOURCE_TABLES = (
    'users','user_kv','canary_users','canary_user_kv','user_rating','user_tag_rating',
    'rating_submission','solve_history','user_habit','arena_rating','ocr_jobs',
)

def bundle(*, rollback: bool) -> str:
    parts = ["begin;\nset local lock_timeout='5s';\nset local statement_timeout='60s';\n",
             "create schema if not exists aiflow_api_cutover_20261012;\n"
             "revoke all on schema aiflow_api_cutover_20261012 from public,anon,authenticated,service_role;\n"]
    parts.append('lock table ' + ','.join('public.'+table for table in SOURCE_TABLES)
                 + ' in share row exclusive mode;\n')
    for table in SOURCE_TABLES:
        parts.append(f'create table if not exists aiflow_api_cutover_20261012.{table} as table public.{table};\n')
        parts.append(f'alter table aiflow_api_cutover_20261012.{table} enable row level security;\n')
    parts.append('revoke all on all tables in schema aiflow_api_cutover_20261012 from public,anon,authenticated,service_role;\n')
    # Match answers are deliberately transient, including in a recovery snapshot.
    parts.append("update aiflow_api_cutover_20261012.canary_user_kv "
                 "set value=(value::jsonb-'answers')::text "
                 "where key='arena.active_match' and value::jsonb ? 'answers';\n")
    for name in FILES:
        sql = (ROOT/'deploy'/'vercel'/name).read_text(encoding='utf-8')
        lines = [line for line in sql.splitlines() if line.strip().lower() not in ('begin;', 'commit;')]
        parts.append('\n-- ' + name + '\n' + '\n'.join(lines) + '\n')
    parts.append('savepoint api_cutover_smoke;\n')
    parts.append((ROOT/'deploy'/'vercel'/'supabase_product_api_smoke.sql').read_text(encoding='utf-8'))
    parts.append('\nrollback to savepoint api_cutover_smoke;\n')
    parts.append("notify pgrst,'reload schema';\n")
    parts.append('rollback;\n' if rollback else 'commit;\n')
    return ''.join(parts)

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rollback',action='store_true',help='SQL execution test; discard all changes')
    args=parser.parse_args()
    branch=subprocess.check_output(['git','-c',f'safe.directory={ROOT.as_posix()}',
                                    'branch','--show-current'],cwd=ROOT,text=True).strip()
    if Path.cwd().resolve()!=ROOT or ROOT.drive.upper()!='D:' or branch!='hotfix':
        raise RuntimeError('cutover preparation requires the D: hotfix checkout')
    suffix='preflight' if args.rollback else 'apply'
    output=ROOT/'build'/'temp'/f'product-api-cutover-{suffix}.sql'
    sql=bundle(rollback=args.rollback)
    output.write_text(sql,encoding='utf-8',newline='\n')
    print(f'{output}: bytes={len(sql.encode())} sha256={hashlib.sha256(sql.encode()).hexdigest()}')

if __name__=='__main__':
    main()
