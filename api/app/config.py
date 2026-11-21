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
        )
