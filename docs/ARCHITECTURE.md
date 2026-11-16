# BrainWake architecture

## The pieces

```
  Phone app  ───────────────►  Supabase
  (Flutter)   sign in,          accounts (email + Google)
              download banks,   database (question bank, user data)
              back up progress  storage  (question pictures)
      │                              ▲
      │ "write questions",           │ service key
      │ "explain my answer"          │ (server only)
      ▼                              │
  BrainWake API  ────────────────────┘
  (Azure VM)      checks who is asking, enforces the daily AI limit,
      │           calls Gemini with the key only the server has
      ▼
   Gemini

  Admin website (Azure VM) ──► Supabase, signed in as an admin
```

- **The app works offline.** Alarms, saved questions and explanations never
  need the network. The server adds: fresh question banks, AI, and backup.
- **Supabase holds all data.** The Azure side stores nothing, so it can be
  moved to another host without migrating anything.
- **No key is ever in the app.** The app only has Supabase's public
  ("anon") key, which is safe to ship because the database rules decide
  what it can do.

## Database

| Table | What it holds | Who can read | Who can write |
|---|---|---|---|
| `profiles` | One row per account; `role` is `user` or `admin` | Yourself; admins | Yourself (not your role); admins |
| `units`, `topics` | The structure of the question bank | Everyone | Admins |
| `questions` | Text, 5 options or none, answer, accepted alternatives, explanation, picture, `draft`/`published` | Everyone (published only); admins (all) | Admins |
| `user_sessions` | Each alarm ring or practice session | Its owner | Its owner |
| `user_attempts` | Every answer given | Its owner | Its owner |
| `user_questions` | Questions the AI wrote for that user | Its owner | Its owner |
| `user_backups` | A user's alarms and settings, for restoring on a new phone | Its owner | Its owner |
| `ai_usage` | One row per AI call, for daily limits | Its owner | The server only |

Design choices:

- **Reading the bank needs no account**, so the app can download questions
  before anyone signs in.
- **Nothing in the bank is truly deleted.** Rows get a `deleted_at` time
  instead, and every change moves `updated_at` forward. The app asks "what
  changed since my last download?" and so also learns about removals.
- **Uploads from the phone are repeat-safe.** Sessions and answers carry an
  id made on the phone, so sending the same one twice stores it once.
- **AI-written questions go straight to the user who asked.** They are
  private to that user and saved to their account, so they follow them to
  a new phone. They are not added to the shared bank. (Drafts exist only
  for questions an admin is still writing.)
- **A multiple-choice question must have exactly 5 options and its answer
  must be one of them**; the database itself refuses anything else.
- **Deleting an account deletes its data** (answers, sessions, backup, AI
  usage).
- **Admins manage content, not people's data**: the rules do not let an
  admin read other users' answers.

## Question pictures

One public storage bucket, `question-images`. Anyone can view a picture;
only admins can upload, replace or delete. A question stores the picture's
path inside the bucket (`image_path`). The 10 placeholder spotter drawings
are expected at `seed/<name>.png`.

## Still to build

1. Apply the migrations to the Supabase project and upload the seed pictures.
2. Admin website: sign in, manage units / topics / questions, upload
   pictures, review AI drafts.
3. API: `generate questions`, `explain my answer`, `grade my answer`, each
   checking the caller's Supabase sign-in and their daily limit.
4. App: sign-in (email and Google), bank download, progress upload and
   restore, AI through the API, and removal of the API-key screen.
