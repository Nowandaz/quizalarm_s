"""Puts the branded emails (supabase/email/*.html) and the mail sender on
the Supabase project, through the management API.

  python tools/apply_email.py            # templates and subjects only
  SMTP_PASS=... python tools/apply_email.py --smtp   # also the sender

Needs SUPABASE_ACCESS_TOKEN (never commit it). The sender's password is
read from SMTP_PASS and is never stored in this repository.
"""
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

REF = os.environ.get("SUPABASE_PROJECT_REF", "zsplxgvizlndnofsokxw")
TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
FOLDER = pathlib.Path(__file__).resolve().parent.parent / "supabase" / "email"

SUBJECTS = {
    "confirmation": "Confirm your email for Brain O' Clock",
    "recovery": "Set a new Brain O' Clock password",
    "magic_link": "Your Brain O' Clock sign-in link",
    "email_change": "Confirm your new email for Brain O' Clock",
    "invite": "You are invited to Brain O' Clock",
}

# The sender (a Gmail account with an app password).
SMTP = {
    "smtp_host": "smtp.gmail.com",
    "smtp_port": "465",
    "smtp_user": "brainonclock@gmail.com",
    "smtp_admin_email": "brainonclock@gmail.com",
    "smtp_sender_name": "Brain O' Clock",
    # Seconds one person must wait between two emails.
    "smtp_max_frequency": 60,
    # Emails per hour for the whole project (Gmail allows about 500 a day).
    "rate_limit_email_sent": 60,
}


def main():
    body = {}
    for name, subject in SUBJECTS.items():
        body[f"mailer_subjects_{name}"] = subject
        body[f"mailer_templates_{name}_content"] = (FOLDER / f"{name}.html").read_text(encoding="utf-8")
    if "--smtp" in sys.argv:
        password = os.environ.get("SMTP_PASS", "")
        if not password:
            sys.exit("Set SMTP_PASS to the sender's app password.")
        body.update(SMTP, smtp_pass=password)
    request = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{REF}/config/auth",
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json",
                 "User-Agent": "brainwake-tools"},
        method="PATCH",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            saved = json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        sys.exit(f"FAILED: {error.read().decode()[:1500]}")
    # Say what is set now, never the password.
    for key in ("smtp_host", "smtp_port", "smtp_user", "smtp_sender_name", "smtp_admin_email",
                "rate_limit_email_sent", "mailer_subjects_confirmation", "mailer_subjects_recovery"):
        print(f"{key}: {saved.get(key)}")
    print("smtp_pass set:", bool(saved.get("smtp_pass")))


if __name__ == "__main__":
    main()
