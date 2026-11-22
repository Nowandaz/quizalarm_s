# BrainWake server (quizalarm_s)

Everything behind the BrainWake app ([quiz_alarm](https://github.com/Nowandaz/quiz_alarm)):
the database design, and (coming next) the admin website and the small API
that makes AI calls.

| Piece | Runs on | Status |
|---|---|---|
| Database, accounts, picture storage | Supabase project `zsplxgvizlndnofsokxw` | **Live**: tables, security rules, picture bucket, 70 seed questions and their 10 pictures |
| API (AI calls through the saved providers in turn, per-user limits) | Azure VM | **Built and tested**, in `api/` (see `docs/API.md`); not deployed yet |
| Admin website (questions, pictures, accounts, settings, keys) | Runs locally for now; Azure VM later | **Built**, in `admin/` |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit.

## Admin website

Plain HTML and JavaScript in `admin/`, no build step. To run it on your
computer:

```bash
cd admin
python -m http.server 8095
```

Then open http://localhost:8095.

**First time:** create an account with your email, open the confirmation
link Supabase emails you, sign in, and press **Make me the owner**. That
button only exists while the system has no owner.

| Role | Can do |
|---|---|
| Owner | Everything: question bank, accounts (roles, plans, delete), AI settings, keys |
| Admin | Question bank only: units, topics, questions, pictures, import / export |
| User  | Nothing here (the site tells them so) |

What each page does:

- **Dashboard**: counts of units, topics, questions, drafts, accounts,
  recent activity and today's AI calls.
- **Question bank**: add / edit / delete / restore units, topics and
  questions; mark a unit premium; 5-option or typed questions with
  accepted alternatives, explanation, picture upload and draft status;
  import or export a unit as a JSON file in the app's bank format.
- **Alarm reports**: how alarms behaved on people's phones in the last
  7 days (rang, missed, late, by phone model) and the problems people
  reported, each with the diagnostics the app attached and the phone's
  own diary of what happened before.
- **Payments** (owner): income, who paid, what for, how and when, sales
  by plan, and who is on which plan. Plans (names, prices, what they
  offer) and discount codes are under Settings, Plans and codes. See
  `docs/PAYMENTS.md` for setting up Paystack.
- **Accounts** (owner): everyone who signed up, with search; change a
  role or plan; delete an account and its data.
- **Settings** (owner), in two tabs. *AI providers*: add as many as you
  like (Gemini, Groq, OpenAI, OpenRouter, Anthropic, or anything that
  speaks the OpenAI format), each with its own key, model and weight;
  switch them on or off; test a key before saving. The server uses the
  switched-on ones in turn (weighted round robin) and moves to the next
  if one fails. Keys can be replaced or removed, never read back.
  *AI limits*: daily limits for free and premium users, and an AI
  on/off switch.

To look at the site without signing in or touching real data, open
`admin/preview.html`: the same pages on made-up data kept in memory.

`admin/config.js` holds the project address and its publishable key.
Both are public by design; the database rules decide what a signed-in
person may do.

## Layout

```
admin/                 the admin website
api/                   the API server (FastAPI) and its tests
supabase/migrations/   the database, in order:
  0001_schema.sql        tables
  0002_policies.sql      who may read / change what
  0003_storage.sql       bucket for question pictures
  0004_owner_admin.sql   owner role, account management, settings, keys
  0005_ai_providers.sql  AI providers used in turn (round robin)
  0006_alarm_events.sql  alarm diary and problem reports from phones
  0007_review_fixes.sql  fair provider rotation, key safety, withdrawn questions
  0008_delete_my_account.sql  a user can delete their own account
  0009_payments.sql      buying premium through Paystack
  0010_tiers_and_codes.sql  plans the owner defines, and discount codes
  0011_accounts_tier.sql the accounts list shows each account's plan
  0012_access_levels_and_flags.sql  guest/free/paid topics, Pro and Ultra, flagged questions
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
lives only in the API's `.env` on the server. AI provider keys are saved
through the admin site into a table only the server can read.
