"""Emails from the owner to people with accounts, sent from the admin site.

The owner writes a subject and a message; this turns it into the same
branded email as the sign-in emails and sends one copy per person through
the project's mailbox (SMTP). Only admins may send. Every email carries a
link that stops further emails for that person.
"""

import asyncio
import hashlib
import hmac
import html
import logging
import re
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr, make_msgid
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field, StringConstraints

from .config import Settings
from .store import Store, User

log = logging.getLogger("brainwake.mail")

SITE = "https://brainoclock.onrender.com"
# Gmail lets one mailbox write to about 500 people a day. Stay under it,
# leaving room for the sign-in emails that use the same mailbox.
MAX_RECIPIENTS = 400
# Seconds between two emails, so the mailbox is not taken for a spammer.
GAP_SECONDS = 1.5
AUDIENCES = ("all", "free", "paid", "version", "older", "custom")
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class SendRequest(BaseModel):
    subject: Annotated[str, StringConstraints(strip_whitespace=True, min_length=3, max_length=120)]
    body: Annotated[str, StringConstraints(strip_whitespace=True, min_length=3, max_length=5000)]
    audience: str = Field("all", max_length=10)
    app_version: str = Field("", max_length=20)
    # For audience "custom": the addresses to write to.
    emails: list[Annotated[str, StringConstraints(strip_whitespace=True, max_length=200)]] = Field(
        default_factory=list, max_length=MAX_RECIPIENTS)
    button_text: Annotated[str, StringConstraints(strip_whitespace=True, max_length=40)] = ""
    button_url: Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)] = ""
    # True: send one copy to the admin's own address and nobody else.
    test: bool = False


def unsubscribe_code(secret: str, user_id: str) -> str:
    return hmac.new(secret.encode(), f"unsubscribe:{user_id}".encode(), hashlib.sha256).hexdigest()[:32]


def render(subject: str, body: str, button_text: str = "", button_url: str = "", unsubscribe: str = "") -> tuple[str, str]:
    """The email as (plain text, HTML). The message is the owner's own
    words: blank lines separate paragraphs, nothing in it is treated as HTML."""
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", body.strip()) if p.strip()]
    text = "\n\n".join(paragraphs)
    if button_text and button_url:
        text += f"\n\n{button_text}: {button_url}"
    text += "\n\n--\nBrain O' Clock, the alarm that only stops when you answer.\n" + SITE
    if unsubscribe:
        text += f"\nStop these emails: {unsubscribe}"

    e = html.escape
    parts = "".join(
        '<p style="margin:0 0 16px;font-size:16px;line-height:1.6;color:#3d4250;">'
        + e(p).replace("\n", "<br>") + "</p>"
        for p in paragraphs
    )
    button = ""
    if button_text and button_url:
        button = (
            '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:6px 0 24px;"><tr>'
            '<td align="center" bgcolor="#1f4fd1" style="border-radius:12px;">'
            f'<a href="{e(button_url, quote=True)}" style="display:inline-block;padding:14px 28px;font-size:16px;'
            f'font-weight:700;color:#ffffff;text-decoration:none;border-radius:12px;">{e(button_text)}</a>'
            "</td></tr></table>"
        )
    stop = (
        f' &nbsp;·&nbsp; <a href="{e(unsubscribe, quote=True)}" style="color:#8a90a0;">Stop these emails</a>'
        if unsubscribe else ""
    )
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark"><title>{e(subject)}</title></head>
<body style="margin:0;padding:0;background:#f2f3f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#16181d;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f2f3f7;">
<tr><td align="center" style="padding:28px 14px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">
    <tr><td align="center" style="background:#05060a;border-radius:18px 18px 0 0;padding:30px 24px 26px;">
      <img src="{SITE}/brand/logo.png" width="72" height="72" alt="Brain O' Clock" style="display:block;border:0;border-radius:16px;">
      <div style="margin-top:14px;font-size:22px;font-weight:800;letter-spacing:-0.3px;color:#ffffff;">Brain O' Clock</div>
      <div style="margin-top:4px;font-size:11px;font-weight:700;letter-spacing:2.5px;color:#8ab4f8;">THE QUIZ ALARM</div>
    </td></tr>
    <tr><td style="background:#ffffff;border-radius:0 0 18px 18px;padding:32px 30px 14px;">
      <h1 style="margin:0 0 14px;font-size:22px;line-height:1.3;font-weight:800;color:#16181d;">{e(subject)}</h1>
      {parts}{button}
    </td></tr>
    <tr><td align="center" style="padding:18px 10px 0;">
      <p style="margin:0;font-size:12px;line-height:1.6;color:#8a90a0;">You get this because you have a Brain O' Clock account.<br>
        <a href="{SITE}/terms.html" style="color:#8a90a0;">Terms</a> &nbsp;·&nbsp;
        <a href="{SITE}/privacy.html" style="color:#8a90a0;">Privacy</a>{stop}</p>
    </td></tr>
  </table>
</td></tr></table>
</body></html>"""
    return text, page


class SmtpMailer:
    """Sends through the mailbox in the settings. One connection is opened
    for a batch and closed after it."""

    def __init__(self, settings: Settings):
        self._s = settings
        self._server: smtplib.SMTP | None = None

    def open(self) -> None:
        s = self._s
        context = ssl.create_default_context()
        if s.smtp_port == 465:
            server: smtplib.SMTP = smtplib.SMTP_SSL(s.smtp_host, s.smtp_port, timeout=30, context=context)
        else:
            server = smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=30)
            server.starttls(context=context)
        server.login(s.smtp_user, s.smtp_password)
        self._server = server

    def send(self, to: str, subject: str, text: str, page: str, unsubscribe: str = "") -> None:
        s = self._s
        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = formataddr((s.mail_from_name, s.smtp_user))
        message["To"] = to
        message["Message-ID"] = make_msgid(domain=s.smtp_user.split("@")[-1])
        if unsubscribe:
            message["List-Unsubscribe"] = f"<{unsubscribe}>"
        message.set_content(text)
        message.add_alternative(page, subtype="html")
        assert self._server is not None, "open() first"
        self._server.send_message(message)

    def close(self) -> None:
        try:
            if self._server is not None:
                self._server.quit()
        except Exception:
            pass
        self._server = None


UNSUBSCRIBED_PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Emails stopped</title>
<style>body{font-family:system-ui,sans-serif;background:#0b0b0d;color:#f4f4f5;
display:grid;place-items:center;min-height:100vh;margin:0;text-align:center;padding:24px}
h1{font-size:26px;margin:0 0 8px}p{color:#a1a1aa;margin:0;max-width:340px;line-height:1.5}</style>
</head><body><div><h1>Done</h1>
<p>You will not get any more news emails from Brain O' Clock. Emails you ask for yourself, such as a password reset, still arrive.</p>
</div></body></html>"""


def build_router(caller, gap_seconds: float = GAP_SECONDS) -> APIRouter:
    router = APIRouter()

    async def admin(request: Request, user: User) -> Store:
        store: Store = request.app.state.store
        if await store.role_of(user.id) != "owner":
            raise HTTPException(403, "Only the owner can send emails.")
        return store

    def unsubscribe_link(settings: Settings, user_id: str) -> str:
        if not user_id or not settings.public_url:
            return ""
        return f"{settings.public_url}/unsubscribe?u={user_id}&c={unsubscribe_code(settings.secret_key, user_id)}"

    async def deliver(request: Request, campaign: str | None, people: list[dict], body: SendRequest) -> tuple[int, int, str]:
        """Sends one copy to each of [people] ({email, user_id}). Returns
        (sent, failed, first error)."""
        settings: Settings = request.app.state.settings
        store: Store = request.app.state.store
        mailer = request.app.state.mailer
        sent = failed = 0
        error = ""
        try:
            await asyncio.to_thread(mailer.open)
        except Exception as problem:  # wrong password, mailbox unreachable
            log.error("mailbox: %s", type(problem).__name__)
            error = f"Could not sign in to the mailbox ({type(problem).__name__})."
            if campaign:
                await store.update_campaign(campaign, status="stopped", sent=0, failed=len(people), error=error)
            return 0, len(people), error
        try:
            for index, person in enumerate(people):
                # No "stop these emails" link for now (the owner's choice:
                # people must not miss key emails such as a new version).
                # To bring it back: link = unsubscribe_link(settings, person.get("user_id") or "")
                link = ""
                text, page = render(body.subject, body.body, body.button_text, body.button_url, link)
                try:
                    await asyncio.to_thread(mailer.send, person["email"], body.subject, text, page, link)
                    sent += 1
                except Exception as problem:
                    failed += 1
                    error = error or f"{type(problem).__name__}"
                    log.error("email not sent: %s", type(problem).__name__)
                    # The mailbox hung up (often its daily limit): stop here.
                    if isinstance(problem, (smtplib.SMTPServerDisconnected, smtplib.SMTPSenderRefused)):
                        failed += len(people) - index - 1
                        break
                if campaign and (index % 10 == 9):
                    await store.update_campaign(campaign, sent=sent, failed=failed)
                if index < len(people) - 1 and gap_seconds:
                    await asyncio.sleep(gap_seconds)
        finally:
            await asyncio.to_thread(mailer.close)
            if campaign:
                await store.update_campaign(
                    campaign, sent=sent, failed=failed, error=error,
                    status="done" if sent + failed >= len(people) and not (failed and not sent) else "stopped",
                )
        return sent, failed, error

    @router.get("/v1/admin/email/status")
    async def status(request: Request, user: User = caller):
        await admin(request, user)
        settings: Settings = request.app.state.settings
        return {"ready": settings.mail_ready, "from": settings.smtp_user, "your_email": user.email,
                "max_recipients": MAX_RECIPIENTS}

    @router.post("/v1/admin/email/send")
    async def send(body: SendRequest, request: Request, user: User = caller):
        store = await admin(request, user)
        settings: Settings = request.app.state.settings
        if not settings.mail_ready:
            raise HTTPException(503, "Email is not set up on this server yet (the SMTP settings are missing).")
        if body.audience not in AUDIENCES:
            raise HTTPException(422, "Unknown audience.")
        if bool(body.button_text) != bool(body.button_url):
            raise HTTPException(422, "A button needs both its text and its address.")
        if body.button_url and not body.button_url.startswith("https://"):
            raise HTTPException(422, "The button's address must start with https://")

        if body.test:
            if not user.email:
                raise HTTPException(422, "Your account has no email address.")
            sent, _, error = await deliver(request, None, [{"email": user.email, "user_id": ""}], body)
            if not sent:
                raise HTTPException(502, error or "The test email could not be sent.")
            return {"sent": 1, "to": user.email}

        if body.audience == "custom":
            seen: dict[str, dict] = {}
            for address in body.emails:
                if not EMAIL.match(address):
                    raise HTTPException(422, f"Not an email address: {address}")
                seen.setdefault(address.lower(), {"email": address, "user_id": ""})
            people = list(seen.values())
        else:
            if body.audience == "version" and not body.app_version:
                raise HTTPException(422, "Choose the app version.")
            people = await store.email_recipients(body.audience, body.app_version)
        if not people:
            raise HTTPException(422, "Nobody matches, so nothing was sent.")
        if len(people) > MAX_RECIPIENTS:
            raise HTTPException(
                422, f"That is {len(people)} people. The mailbox can write to about {MAX_RECIPIENTS} a day; "
                     "choose a smaller group.")

        campaign = await store.add_campaign({
            "created_by": user.id, "subject": body.subject, "body": body.body,
            "button_text": body.button_text, "button_url": body.button_url,
            "audience": body.audience, "app_version": body.app_version, "total": len(people),
        })
        # Sending takes a while (one every second or two): carry on after
        # answering, and let the admin site show the progress.
        task = asyncio.create_task(deliver(request, campaign, people, body))
        request.app.state.mail_tasks.add(task)
        task.add_done_callback(request.app.state.mail_tasks.discard)
        return {"campaign": campaign, "recipients": len(people)}

    @router.get("/unsubscribe", response_class=HTMLResponse)
    async def unsubscribe(request: Request, u: str = Query("", max_length=40), c: str = Query("", max_length=64)):
        settings: Settings = request.app.state.settings
        if not re.fullmatch(r"[0-9a-fA-F-]{36}", u) or not hmac.compare_digest(
                unsubscribe_code(settings.secret_key, u), c):
            raise HTTPException(404, "This link is not valid.")
        await request.app.state.store.stop_emails(u)
        return UNSUBSCRIBED_PAGE

    return router
