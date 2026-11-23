#!/usr/bin/env bash
# Tests the database design on a throw-away local PostgreSQL database:
# applies the migrations (except storage, which only exists on Supabase),
# loads the seed if present, and runs the security checks.
#
#   tools/test_db.sh            (needs a local PostgreSQL you can administer)
#
# Set PSQL to change how psql is run, e.g. PSQL="psql -U postgres".
set -euo pipefail
cd "$(dirname "$0")/.."
PSQL="${PSQL:-psql}"
DB="brainwake_test_$$"

$PSQL -q -d postgres -c "create database $DB"
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT

run() { $PSQL -q -v ON_ERROR_STOP=1 -d "$DB" -f "$1"; }
run supabase/tests/00_supabase_stub.sql
run supabase/migrations/0001_schema.sql
run supabase/migrations/0002_policies.sql
run supabase/migrations/0004_owner_admin.sql
run supabase/migrations/0005_ai_providers.sql
run supabase/migrations/0006_alarm_events.sql
run supabase/migrations/0007_review_fixes.sql
run supabase/migrations/0008_delete_my_account.sql
run supabase/migrations/0009_payments.sql
run supabase/migrations/0010_tiers_and_codes.sql
run supabase/migrations/0011_accounts_tier.sql
run supabase/migrations/0012_access_levels_and_flags.sql
run supabase/migrations/0014_usage_stats.sql
run supabase/migrations/0015_install_devices.sql
run supabase/migrations/0016_one_row_per_phone.sql
run supabase/migrations/0017_app_releases.sql
run supabase/migrations/0018_homepage_questions.sql
$PSQL -q -d "$DB" -c "grant all on all tables in schema public to service_role;
                      grant usage, select on all sequences in schema public to service_role, authenticated;"
if [ -f supabase/seed.sql ]; then
  run supabase/seed.sql
  $PSQL -At -d "$DB" -c "select 'seed: ' || (select count(*) from units) || ' units, ' ||
    (select count(*) from topics) || ' topics, ' || (select count(*) from questions) || ' questions'"
  $PSQL -q -d "$DB" -c "truncate public.units cascade"
fi
for t in supabase/tests/[0-9][0-9]_test_*.sql; do
  run "$t" 2>&1 | grep -E "ok:|FAILED|ERROR|PASSED" || true
done
