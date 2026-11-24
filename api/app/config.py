"""Settings, read once from environment variables (see .env.example)."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    publishable_key: str
    secret_key: str
    # Paystack secret key. Empty = payments are not set up on this server.
    paystack_key: str = ""
    # This server's public address (no trailing slash), for the page
    # Paystack sends people back to after paying.
    public_url: str = ""
    # The mailbox that sends the owner's emails (SMTP). Empty = not set up.
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    mail_from_name: str = "Brain O' Clock"

    @property
    def mail_ready(self) -> bool:
        return bool(self.smtp_host and self.smtp_user and self.smtp_password)

    @staticmethod
    def from_env() -> "Settings":
        def need(name: str) -> str:
            value = os.environ.get(name, "").strip()
            if not value:
                raise RuntimeError(f"{name} is not set (see api/.env.example)")
            return value

        return Settings(
            supabase_url=need("SUPABASE_URL").rstrip("/"),
            publishable_key=need("SUPABASE_PUBLISHABLE_KEY"),
            secret_key=need("SUPABASE_SECRET_KEY"),
            paystack_key=os.environ.get("PAYSTACK_SECRET_KEY", "").strip(),
            public_url=os.environ.get("PUBLIC_URL", "").strip().rstrip("/"),
            smtp_host=os.environ.get("SMTP_HOST", "").strip(),
            smtp_port=int(os.environ.get("SMTP_PORT", "").strip() or 587),
            smtp_user=os.environ.get("SMTP_USER", "").strip(),
            # An app password is shown with spaces; they are not part of it.
            smtp_password=os.environ.get("SMTP_PASSWORD", "").replace(" ", ""),
            mail_from_name=os.environ.get("MAIL_FROM_NAME", "").strip() or "Brain O' Clock",
        )
