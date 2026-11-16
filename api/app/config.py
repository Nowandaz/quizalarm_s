"""Settings, read once from environment variables (see .env.example)."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    publishable_key: str
    secret_key: str

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
        )
