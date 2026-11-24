"""Everything this server asks of Supabase: who a token belongs to, the
user's plan, settings, usage counts, and the next AI provider.

Calls made with the secret key bypass the database rules, so every function
here is deliberately narrow.
"""

import hashlib
import time
from dataclasses import dataclass
from datetime import datetime, timezone

import httpx

from .config import Settings

CACHE_SECONDS = 60
# Kinds of AI call that count towards the daily limit. Grading a typed
# answer is tiny and happens while an alarm rings, so it is recorded but
# never blocked by the limit.
COUNTED_KINDS = ("generate", "feedback")


class StoreError(Exception):
    """Supabase could not be reached or answered unexpectedly."""


@dataclass(frozen=True)
class User:
    id: str
    premium: bool
    email: str = ""
    # The paid tier the account is on ("" = none, or premium given by hand).
    tier: str = ""


@dataclass(frozen=True)
class Provider:
    id: str
    name: str
    type: str  # openai | gemini | anthropic
    api_key: str
    endpoint: str
    model: str


class Store:
    def __init__(self, settings: Settings, http: httpx.AsyncClient):
        self._s = settings
        self._http = http
        self._users: dict[str, tuple[float, User]] = {}
        self._config: tuple[float, dict] | None = None
        self._tiers: tuple[float, list[dict]] | None = None

    # ------------------------------------------------------------ plumbing

    def _server_headers(self) -> dict[str, str]:
        key = self._s.secret_key
        return {"apikey": key, "Authorization": f"Bearer {key}"}

    async def _request(self, method: str, path: str, **kwargs) -> httpx.Response:
        try:
            response = await self._http.request(
                method, f"{self._s.supabase_url}{path}", timeout=10, **kwargs
            )
        except httpx.HTTPError as error:
            raise StoreError(f"Supabase unreachable: {type(error).__name__}") from error
        return response

    async def _rest(self, method: str, path: str, **kwargs) -> httpx.Response:
        headers = {**self._server_headers(), **kwargs.pop("headers", {})}
        response = await self._request(method, f"/rest/v1{path}", headers=headers, **kwargs)
        if response.status_code >= 400:
            raise StoreError(f"Supabase answered {response.status_code} for {path.split('?')[0]}")
        return response

    # --------------------------------------------------------------- users

    async def user_for_token(self, token: str) -> User | None:
        """The signed-in user a token belongs to, or None if it is not valid.
        Supabase itself checks the token; the answer is remembered briefly."""
        digest = hashlib.sha256(token.encode()).hexdigest()
        cached = self._users.get(digest)
        if cached and cached[0] > time.monotonic():
            return cached[1]

        response = await self._request(
            "GET",
            "/auth/v1/user",
            headers={"apikey": self._s.publishable_key, "Authorization": f"Bearer {token}"},
        )
        if response.status_code in (401, 403):
            return None
        if response.status_code != 200:
            raise StoreError(f"Supabase sign-in check answered {response.status_code}")
        account = response.json()
        user_id = account.get("id")
        if not user_id:
            return None

        rows = (
            await self._rest(
                "GET", "/profiles", params={"id": f"eq.{user_id}", "select": "plan,plan_expires_at,tier"}
            )
        ).json()
        user = User(
            id=user_id,
            premium=bool(rows) and _is_premium(rows[0]),
            email=account.get("email") or "",
            tier=(rows[0].get("tier") or "") if rows else "",
        )
        if len(self._users) > 5000:
            self._users.clear()
        self._users[digest] = (time.monotonic() + CACHE_SECONDS, user)
        return user

    # -------------------------------------------------------------- emails

    async def role_of(self, user_id: str) -> str:
        """'user', 'admin' or 'owner'. Asked each time: it guards sending."""
        rows = (await self._rest("GET", "/profiles", params={"id": f"eq.{user_id}", "select": "role"})).json()
        return (rows[0].get("role") or "user") if rows else "user"

    async def email_recipients(self, audience: str, app_version: str) -> list[dict]:
        """The accounts an email goes to: [{user_id, email}]."""
        response = await self._rest(
            "POST", "/rpc/email_recipients", json={"audience": audience, "app_version": app_version}
        )
        return [row for row in response.json() if row.get("email")]

    async def add_campaign(self, row: dict) -> str:
        response = await self._rest(
            "POST", "/email_campaigns", json=row, headers={"Prefer": "return=representation"}
        )
        return response.json()[0]["id"]

    async def update_campaign(self, campaign: str, **changes) -> None:
        try:
            await self._rest("PATCH", "/email_campaigns", params={"id": f"eq.{campaign}"}, json=changes)
        except StoreError:
            pass  # the emails matter more than the count shown for them

    async def stop_emails(self, user_id: str) -> None:
        await self._rest("PATCH", "/profiles", params={"id": f"eq.{user_id}"}, json={"email_updates": False})

    # ------------------------------------------------------------ settings

    async def config(self) -> dict:
        """The owner's settings from the admin site (remembered briefly)."""
        if self._config and self._config[0] > time.monotonic():
            return self._config[1]
        rows = (await self._rest("GET", "/app_config", params={"select": "key,value"})).json()
        values = {row["key"]: row["value"] for row in rows}
        self._config = (time.monotonic() + CACHE_SECONDS, values)
        return values

    # --------------------------------------------------------------- usage

    async def used_today(self, user_id: str) -> int:
        """Counted AI calls the user has made since midnight UTC."""
        start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        response = await self._rest(
            "GET",
            "/ai_usage",
            params={
                "user_id": f"eq.{user_id}",
                "created_at": f"gte.{start.isoformat()}",
                "kind": f"in.({','.join(COUNTED_KINDS)})",
                "select": "id",
                "limit": "1",
            },
            headers={"Prefer": "count=exact"},
        )
        # Content-Range looks like "0-0/7" or "*/0".
        total = response.headers.get("content-range", "").rpartition("/")[2]
        if not total.isdigit():
            raise StoreError("Supabase did not return a usage count")
        return int(total)

    async def record_use(self, user_id: str, kind: str) -> int | None:
        """Notes one AI call and returns the note's id (see release_use)."""
        rows = (
            await self._rest(
                "POST",
                "/ai_usage",
                json={"user_id": user_id, "kind": kind},
                headers={"Prefer": "return=representation"},
            )
        ).json()
        return rows[0].get("id") if rows else None

    async def release_use(self, use_id: int | None) -> None:
        """Takes back a note made for a call that then failed."""
        if use_id is None:
            return
        try:
            await self._rest("DELETE", "/ai_usage", params={"id": f"eq.{use_id}"})
        except StoreError:
            pass

    # ------------------------------------------------------------ payments

    def forget_user(self, user_id: str) -> None:
        """Drops what is remembered about a user (their plan just changed)."""
        self._users = {k: v for k, v in self._users.items() if v[1].id != user_id}

    async def tiers(self) -> list[dict]:
        """The paid tiers the owner defined, in display order (remembered briefly)."""
        if self._tiers and self._tiers[0] > time.monotonic():
            return self._tiers[1]
        rows = (
            await self._rest("GET", "/tiers", params={"select": "*", "order": "sort_order,name"})
        ).json()
        self._tiers = (time.monotonic() + CACHE_SECONDS, rows)
        return rows

    async def plan_of(self, user_id: str) -> dict:
        rows = (
            await self._rest(
                "GET", "/profiles", params={"id": f"eq.{user_id}", "select": "plan,plan_expires_at,tier"}
            )
        ).json()
        row = rows[0] if rows else {}
        premium = _is_premium(row)
        tier = (row.get("tier") or "") if premium else ""
        name = next((t["name"] for t in await self.tiers() if t["id"] == tier), "")
        return {
            "premium": premium,
            "tier": tier,
            "tier_name": name or ("Premium" if premium else ""),
            "expires": row.get("plan_expires_at") if premium else None,
        }

    async def quote(self, tier: str, period: str, code: str) -> dict:
        """The price of a tier for a period with a code applied; worked out
        in the database, the one place prices are decided."""
        response = await self._rest(
            "POST",
            "/rpc/quote_payment",
            json={"want_tier": tier, "want_period": period, "want_code": code},
        )
        return response.json()

    async def start_payment(self, row: dict) -> None:
        await self._rest("POST", "/payments", json=row, headers={"Prefer": "return=minimal"})

    async def payment(self, reference: str, user_id: str) -> dict | None:
        rows = (
            await self._rest(
                "GET",
                "/payments",
                params={
                    "reference": f"eq.{reference}",
                    "user_id": f"eq.{user_id}",
                    "select": "reference,plan,days,amount,currency,status",
                },
            )
        ).json()
        return rows[0] if rows else None

    async def apply_payment(self, reference: str, amount: int, currency: str, channel: str) -> str:
        """Marks a payment as paid and adds its days (the database checks the
        amount). Returns 'paid', 'failed' or 'unknown'."""
        response = await self._rest(
            "POST",
            "/rpc/apply_payment",
            json={
                "pay_reference": reference,
                "paid_amount": amount,
                "paid_currency": currency,
                "pay_channel": channel,
            },
        )
        return str(response.json())

    # ----------------------------------------------------------- providers

    async def pick_provider(self, skip: list[str]) -> Provider | None:
        """The next provider in round-robin order, leaving out failed ones."""
        rows = (await self._rest("POST", "/rpc/pick_ai_provider", json={"skip": skip})).json()
        if not rows:
            return None
        row = rows[0]
        return Provider(
            id=row["id"],
            name=row["name"],
            type=row["type"],
            api_key=row["api_key"],
            endpoint=row.get("endpoint") or "",
            model=row.get("model") or "",
        )

    async def report_provider_error(self, provider_id: str, text: str) -> None:
        try:
            await self._rest(
                "POST",
                "/rpc/report_ai_provider_error",
                json={"provider_id": provider_id, "error_text": text},
            )
        except StoreError:
            pass  # a failed note about a failure must not fail the request


def _is_premium(profile: dict) -> bool:
    if profile.get("plan") != "premium":
        return False
    expires = profile.get("plan_expires_at")
    if not expires:
        return True
    try:
        return datetime.fromisoformat(expires.replace("Z", "+00:00")) > datetime.now(timezone.utc)
    except ValueError:
        return False
