"""Runs a SQL file (or a query given with -c) on the Supabase project
through the management API.

  python tools/run_sql.py supabase/migrations/0001_schema.sql
  python tools/run_sql.py -c "select count(*) from public.questions"

Needs a Supabase account access token in SUPABASE_ACCESS_TOKEN (never
commit it). The project id comes from SUPABASE_PROJECT_REF.
"""
import json
import os
import sys
import urllib.error
import urllib.request

REF = os.environ.get("SUPABASE_PROJECT_REF", "zsplxgvizlndnofsokxw")
TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN", "")


def run(sql):
    request = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{REF}/database/query",
        data=json.dumps({"query": sql}).encode(),
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "brainwake-tools",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return True, json.loads(response.read().decode() or "[]")
    except urllib.error.HTTPError as error:
        return False, error.read().decode()[:2000]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sql = sys.argv[2] if sys.argv[1] == "-c" else open(sys.argv[1], encoding="utf-8").read()
    ok, result = run(sql)
    print(json.dumps(result, indent=1) if ok else f"FAILED: {result}")
    sys.exit(0 if ok else 1)
