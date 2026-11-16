# BrainWake server (quizalarm_s)

Everything behind the BrainWake app ([quiz_alarm](https://github.com/Nowandaz/quiz_alarm)):
the database design, and (coming next) the admin website and the small API
that makes AI calls.

| Piece | Runs on | Status |
|---|---|---|
| Database, accounts, picture storage | Supabase project `zsplxgvizlndnofsokxw` | **Live**: tables, security rules, picture bucket, 70 seed questions and their 10 pictures |
| API (AI calls with the Gemini key, per-user limits) | Azure VM | Not started |
| Admin website (manage questions and pictures) | Azure VM | Not started |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit.

## Layout

```
supabase/migrations/   the database, in order:
  0001_schema.sql        tables
  0002_policies.sql      who may read / change what
  0003_storage.sql       bucket for question pictures
supabase/seed.sql      the app's bundled questions, as rows (generated)
supabase/tests/        security checks, run on a local PostgreSQL
tools/make_seed.py     regenerates seed.sql from the app's JSON banks
tools/test_db.sh       applies the migrations locally and runs the checks
tools/run_sql.py       runs a SQL file on the live project
```

## Testing the database design

Needs a local PostgreSQL (nothing touches Supabase):

```bash
tools/test_db.sh
```

It creates a throw-away database, applies migrations 0001 and 0002, loads
the seed, and acts as a visitor, two users and an admin to check every
rule. It ends with `ALL POLICY TESTS PASSED`.

## Changing the live database

The migrations in `supabase/migrations/` are already applied. For a later
change, add a new numbered file there, test it with `tools/test_db.sh`,
then run it:

```bash
SUPABASE_ACCESS_TOKEN=... python tools/run_sql.py supabase/migrations/0004_something.sql
```

The token is a Supabase account access token (Account preferences, Access
Tokens). Never commit it.

To make someone an admin (after they have signed up once):

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'you@example.com');
```

## Secrets

No key or password belongs in this repository. The Supabase service key
and the Gemini key live only in the API's `.env` on the server.
