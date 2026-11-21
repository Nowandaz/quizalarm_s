"""Buying a paid tier through Paystack, inside the app.

    GET  /v1/pay/plans     the tiers on sale, and the caller's plan
    POST /v1/pay/quote     the price of a tier with a discount code applied
    POST /v1/pay/start     begin a payment:
                             method "mpesa": Paystack sends a prompt to the
                               phone, the user types their M-Pesa PIN
                             method "card": returns Paystack's card page,
                               which the app shows inside itself
                             a 100% code: nothing to pay, granted at once
    GET  /v1/pay/verify    did this payment go through? (the app asks while
                           it waits)
    POST /v1/pay/webhook   Paystack telling us about a charge (no sign-in;
                           proved by a signature made with our secret key)
    GET  /paid             where Paystack's card page ends up; the app
                           notices this address and closes the page

The amount is decided in the DATABASE from the owner's tiers and codes
(quote_payment), never taken from the app, and checked again there before
any premium time is added. Card numbers never touch this server or the app:
they are typed into Paystack's own page.
"""

import hashlib
import hmac
import json
import logging
import re
import uuid

import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from .config import Settings
from .store import Store, User

log = logging.getLogger("brainwake.pay")

PAYSTACK = "https://api.paystack.co"
PERIODS = {"month": 30, "year": 365}  # period -> days


class QuoteRequest(BaseModel):
    tier: str = Field(max_length=40)
    period: str = Field(max_length=10)
    code: str = Field("", max_length=40)


class StartRequest(QuoteRequest):
    method: str = Field("card", max_length=10)   # "mpesa" or "card"
    phone: str = Field("", max_length=20)        # for M-Pesa


PAID_PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Thank you</title>
<style>body{font-family:system-ui,sans-serif;background:#0b0b0d;color:#f4f4f5;
display:grid;place-items:center;min-height:100vh;margin:0;text-align:center;padding:24px}
h1{font-size:26px;margin:0 0 8px}p{color:#a1a1aa;margin:0;max-width:320px;line-height:1.5}</style>
</head><body><div><h1>Thank you</h1>
<p>Go back to the app. Your plan updates there as soon as the payment is confirmed.</p>
</div></body></html>"""


def valid_signature(secret: str, body: bytes, signature: str) -> bool:
    """Paystack signs each message with HMAC-SHA512 of the body, keyed with
    our secret key."""
    if not secret or not signature:
        return False
    expected = hmac.new(secret.encode(), body, hashlib.sha512).hexdigest()
    return hmac.compare_digest(expected, signature.strip().lower())


def kenyan_phone(typed: str) -> str | None:
    """A Kenyan mobile number as Paystack wants it (+2547XXXXXXXX), from
    the ways people type one: 0712 345 678, 712345678, 254712345678..."""
    digits = re.sub(r"\D", "", typed)
    if digits.startswith("254"):
        digits = digits[3:]
    elif digits.startswith("0"):
        digits = digits[1:]
    if len(digits) == 9 and digits[0] in "17":
        return f"+254{digits}"
    return None


async def offer(store: Store, settings: Settings) -> dict:
    """What is for sale right now."""
    config = await store.config()
    currency = str(config.get("premium_currency") or "KES").upper()
    tiers = []
    for tier in await store.tiers():
        options = [
            {"period": period, "days": days, "price": float(tier[f"price_{period}"])}
            for period, days in PERIODS.items()
            if tier.get(f"price_{period}")
        ]
        if tier.get("active") and options:
            tiers.append({
                "id": tier["id"], "name": tier["name"], "description": tier.get("description") or "",
                "features": [str(f) for f in tier.get("features") or []],
                "ai_daily_limit": tier.get("ai_daily_limit"),
                "premium_units": bool(tier.get("premium_units")),
                "options": options,
            })
    enabled = bool(settings.paystack_key) and config.get("payments_enabled") is True and bool(tiers)
    return {
        "enabled": enabled,
        "currency": currency,
        "tiers": tiers,
        # M-Pesa prompts exist for Kenyan shillings only.
        "methods": (["mpesa"] if currency == "KES" else []) + ["card"],
    }


def build_router(current_user) -> APIRouter:
    router = APIRouter()

    async def paystack(request: Request, method: str, path: str, **kwargs) -> dict:
        settings: Settings = request.app.state.settings
        try:
            response = await request.app.state.http.request(
                method,
                f"{PAYSTACK}{path}",
                headers={"Authorization": f"Bearer {settings.paystack_key}"},
                timeout=25,
                **kwargs,
            )
        except httpx.HTTPError as error:
            log.error("paystack unreachable: %s", type(error).__name__)
            raise HTTPException(503, "The payment service cannot be reached. Try again shortly.")
        try:
            data = response.json()
        except ValueError:
            data = {}
        if response.status_code >= 400 or not data.get("status"):
            message = str(data.get("message") or "")
            log.error("paystack %s %s -> %s %s", method, path, response.status_code, message)
            raise HTTPException(502, "The payment service refused the request. Try again later.")
        return data.get("data") or {}

    async def confirm(store: Store, charge: dict) -> str:
        """Applies a successful charge reported by Paystack."""
        status = await store.apply_payment(
            str(charge.get("reference") or ""),
            int(charge.get("amount") or 0),
            str(charge.get("currency") or ""),
            str(charge.get("channel") or ""),
        )
        if status == "failed":
            log.error("payment %s did not match what was asked for", charge.get("reference"))
        return status

    async def priced(store: Store, body: QuoteRequest) -> dict:
        """The database's price for what was asked, or a 422 saying why not."""
        if body.period not in PERIODS:
            raise HTTPException(422, "That plan does not exist.")
        quote = await store.quote(body.tier, body.period, body.code)
        if not quote.get("ok"):
            raise HTTPException(422, quote.get("message") or "That plan is not on sale.")
        return quote

    @router.get("/paid", response_class=HTMLResponse)
    async def paid():
        return PAID_PAGE

    @router.get("/v1/pay/plans")
    async def plans(request: Request, user: User = current_user):
        store: Store = request.app.state.store
        return {**await offer(store, request.app.state.settings), **await store.plan_of(user.id)}

    @router.post("/v1/pay/quote")
    async def quote(body: QuoteRequest, request: Request, user: User = current_user):
        q = await priced(request.app.state.store, body)
        return {
            "price": q["price"], "full_price": q["full_price"], "percent_off": q["percent_off"],
            "currency": q["currency"], "code": q["code"], "code_message": q["code_message"],
        }

    @router.post("/v1/pay/start")
    async def start(body: StartRequest, request: Request, user: User = current_user):
        store: Store = request.app.state.store
        settings: Settings = request.app.state.settings
        selling = await offer(store, settings)
        if not selling["enabled"]:
            raise HTTPException(503, "Buying a plan is not available yet.")
        q = await priced(store, body)
        if body.code.strip() and not q["code"]:
            # A code that does not work must not quietly turn into full price.
            raise HTTPException(422, q["code_message"] or "That code is not valid.")
        if not user.email:
            raise HTTPException(422, "Your account has no email address to send the receipt to.")

        amount = round(float(q["price"]) * 100)       # Paystack counts in cents
        method = "free" if amount == 0 else body.method
        phone = None
        if method == "mpesa":
            if "mpesa" not in selling["methods"]:
                raise HTTPException(422, "M-Pesa is not available. Pay by card instead.")
            phone = kenyan_phone(body.phone)
            if phone is None:
                raise HTTPException(422, "Enter your M-Pesa number, for example 0712 345 678.")
        elif method not in ("card", "free"):
            raise HTTPException(422, "Choose M-Pesa or card.")

        reference = f"bw_{uuid.uuid4().hex}"
        await store.start_payment({
            "user_id": user.id, "reference": reference, "plan": q["period"], "days": q["days"],
            "amount": amount, "full_amount": round(float(q["full_price"]) * 100),
            "currency": q["currency"], "tier": q["tier"], "code": q["code"] or None,
        })

        if method == "free":
            status = await store.apply_payment(reference, 0, q["currency"], "")
            store.forget_user(user.id)
            return {"reference": reference, "status": status, **await store.plan_of(user.id)}

        if method == "mpesa":
            await paystack(request, "POST", "/charge", json={
                "email": user.email, "amount": amount, "currency": q["currency"],
                "reference": reference, "mobile_money": {"phone": phone, "provider": "mpesa"},
                "metadata": {"tier": q["tier"], "period": q["period"]},
            })
            return {
                "reference": reference, "status": "pending",
                "message": f"Check your phone ({phone}) and enter your M-Pesa PIN.",
            }

        page = await paystack(request, "POST", "/transaction/initialize", json={
            "email": user.email, "amount": amount, "currency": q["currency"],
            "reference": reference, "channels": ["card"],
            "metadata": {"tier": q["tier"], "period": q["period"]},
            **({"callback_url": f"{settings.public_url}/paid"} if settings.public_url else {}),
        })
        url = page.get("authorization_url")
        if not url:
            raise HTTPException(502, "The payment service gave no payment page. Try again later.")
        return {
            "reference": reference, "status": "pending", "url": url,
            # The app closes the card page when it reaches this address.
            "done_url": f"{settings.public_url}/paid" if settings.public_url else "",
        }

    @router.get("/v1/pay/verify")
    async def verify(reference: str, request: Request, user: User = current_user):
        store: Store = request.app.state.store
        payment = await store.payment(reference, user.id)
        if payment is None:
            raise HTTPException(404, "That payment is not one of yours.")
        status = payment["status"]
        if status == "pending" and request.app.state.settings.paystack_key:
            try:
                charge = await paystack(request, "GET", f"/transaction/verify/{reference}")
            except HTTPException:
                # Paystack does not know the payment yet (its page was never
                # opened) or cannot be reached: still waiting, not an error.
                charge = {}
            if charge.get("status") == "success":
                status = await confirm(store, charge)
            elif charge.get("status") in ("failed", "reversed"):
                status = "failed"
        if status == "paid":
            store.forget_user(user.id)
        return {"status": status, **await store.plan_of(user.id)}

    @router.post("/v1/pay/webhook")
    async def webhook(request: Request):
        body = await request.body()
        secret = request.app.state.settings.paystack_key
        if not valid_signature(secret, body, request.headers.get("x-paystack-signature", "")):
            raise HTTPException(401, "Bad signature.")
        try:
            event = json.loads(body)
        except ValueError:
            raise HTTPException(400, "Not JSON.")
        if event.get("event") == "charge.success" and isinstance(event.get("data"), dict):
            await confirm(request.app.state.store, event["data"])
        return {"ok": True}

    return router
