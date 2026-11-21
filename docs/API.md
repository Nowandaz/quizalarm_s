# The API server

A small Python (FastAPI) program in `api/`. It is the only thing that talks
to AI providers. The app sends it a signed-in user's request; it checks who
is asking, applies the daily limit, picks the next provider in turn and
returns the result. AI keys never reach a phone.

## What it answers

Every `/v1` call needs the header `Authorization: Bearer <token>`, where
the token is the one Supabase gives the app when the user signs in.

| Call | Body | Reply |
|---|---|---|
| `GET /health` | - | `{"ok": true}` (no sign-in) |
| `GET /confirmed` | - | a small page shown after the emailed confirmation link |
| `GET /v1/ai/status` | - | `{"enabled", "plan", "limit", "used", "remaining"}` |
| `POST /v1/ai/generate` | `{"subject", "count" (1-10), "avoid": [existing question texts]}` | `{"questions": [{"type", "text", "options", "answer", "alt_answers", "explanation"}], "remaining"}` |
| `POST /v1/ai/feedback` | `{"question", "options", "correct_answer", "explanation", "user_answer", "known_verdict"}` | `{"correct", "feedback", "explanation", "remaining"}` |
| `POST /v1/ai/grade` | `{"question", "correct_answer", "user_answer"}` | `{"correct"}` |
| `GET /v1/pay/plans` | - | `{"enabled", "plans": [{"id", "days", "price", "currency"}], "premium", "expires"}` |
| `POST /v1/pay/start` | `{"plan": "month" or "year"}` | `{"reference", "url"}` (Paystack's payment page) |
| `GET /v1/pay/verify?reference=...` | - | `{"status": "pending", "paid" or "failed", "premium", "expires"}` |
| `POST /v1/pay/webhook` | Paystack's message, signed | `{"ok": true}` (no sign-in) |

Errors come back as `{"detail": "a sentence the app can show"}`:
`401` not signed in, `422` request too big or malformed, `429` daily limit
reached or too many requests in a minute, `503` AI switched off, no
provider working, or the database unreachable.

## Rules it applies

- **Sign-in.** The token is checked with Supabase (remembered for a minute).
- **Daily limit.** `generate` and `feedback` count towards the limit set on
  the admin site (free and premium separately; resets at midnight UTC).
  `grade` is recorded but never blocked: it is tiny and runs while an alarm
  is ringing. A failed request does not use up the allowance.
- **Brake.** At most 30 requests a minute per user.
- **Providers in turn.** It asks the database for the next switched-on
  provider (weighted round robin). If that one fails, or writes something
  unusable, the failure is noted for the admin site and the next provider
  is tried, up to three per request.
- **Fixed prompts.** The prompts live on the server and everything the
  student typed is passed as quoted data, so the API cannot be used as a
  general chatbot. Generated questions are checked (multiple choice has
  exactly 5 different options and the answer is one of them) before they
  are returned.

## Run it on your own computer

```
cd api
pip install -r requirements-dev.txt
python -m pytest                 # 19 tests, no network needed
copy .env.example .env           # then fill in the three values
uvicorn app.main:app --factory --env-file .env --port 8100
```

## Run it on the server

The API shares the Azure server with JARVIS but runs in its own container
with its own settings. JARVIS's Caddy (the HTTPS front door) forwards
`https://<server name>/brainwake/...` to it. Neither project's deploy
restarts the other: if the API is down, only `/brainwake/...` fails.

1. Copy `api\.env.example` to `api\.env` and fill in the three values.
   The secret key is created in the Supabase dashboard (Project settings >
   API keys > Secret keys). `api\.env` is ignored by git and must stay so.
2. From this repository on the laptop:

```
.\deploy\push.ps1 -Server 68.210.230.92 -WithEnv    # first time
.\deploy\push.ps1 -Server 68.210.230.92             # later updates
```

3. Open `https://jarvis-norys.austriaeast.cloudapp.azure.com/brainwake/health`.
   It should show `{"ok":true}`.

The route in Caddy lives in the JARVIS repository (`deploy/Caddyfile`), so
JARVIS must have been deployed once with that route.
