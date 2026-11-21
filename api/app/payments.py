"""Buying premium through Paystack.

    GET  /v1/pay/plans     what can be bought, and the caller's plan
    POST /v1/pay/start     begin a payment; returns Paystack's payment page
    GET  /v1/pay/verify    did this payment go through? (asked by the app
                           when the user comes back from the payment page)
    POST /v1/pay/webhook   Paystack telling us about a charge (no sign-in;
                           proved by a signature made with our secret key)
    GET  /paid             the page Paystack sends the browser to afterwards

The amount to pay is decided HERE from the owner's settings, never taken
from the app, and the database checks it again before any premium time is
added. Two routes confirm a payment (the webhook, and verify when the app
asks); either may come first and applying one twice adds the days once.
"""

import hashlib
import hmac
import json
import logging
import uuid

import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

from .config import Settings
from .store import Store, User

log = logging.getLogger("brainwake.pay")

PAYSTACK = "https://api.paystack.co"
PLANS = {"month": 30, "year": 365}  # plan -> days of premium


class PaymentsOff(Exception):
    """Payments are switched off or not set up."""


class StartRequest(BaseModel):
    plan: str


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


async def offer(store: Store, settings: Settings) -> dict:
    """What is for sale right now."""
    config = await store.config()
    enabled = bool(settings.paystack_key) and config.get("payments_enabled") is True
    currency = str(config.get("premium_currency") or "KES").upper()
    plans = []
    for plan, days in PLANS.items():
        price = config.get(f"premium_price_{plan}")
        if isinstance(price, (int, float)) and not isinstance(price, bool) and price > 0:
            plans.append({"id": plan, "days": days, "price": price, "currency": currency})
    return {"enabled": enabled and bool(plans), "plans": plans}


def build_router(current_user) -> APIRouter:
    router = APIRouter()

    async def paystack(request: Request, method: str, path: str, **kwargs) -> dict:
        settings: Settings = request.app.state.settings
        try:
            response = await request.app.state.http.request(
                method,
                f"{PAYSTACK}{path}",
                headers={"Authorization": f"Bearer {settings.paystack_key}"},
                timeout=20,
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
            log.error("paystack %s %s -> %s %s", method, path, response.status_code, data.get("message"))
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

    @router.get("/paid", response_class=HTMLResponse)
    async def paid():
        return PAID_PAGE

    @router.get("/v1/pay/plans")
    async def plans(request: Request, user: User = current_user):
        store: Store = request.app.state.store
        return {**await offer(store, request.app.state.settings), **await store.plan_of(user.id)}

    @router.post("/v1/pay/start")
    async def start(body: StartRequest, request: Request, user: User = current_user):
        store: Store = request.app.state.store
        settings: Settings = request.app.state.settings
        selling = await offer(store, settings)
        if not selling["enabled"]:
            raise HTTPException(503, "Buying premium is not available yet.")
        plan = next((p for p in selling["plans"] if p["id"] == body.plan), None)
        if plan is None:
            raise HTTPException(422, "That plan does not exist.")
        if not user.email:
            raise HTTPException(422, "Your account has no email address to send the receipt to.")

        reference = f"bw_{uuid.uuid4().hex}"
        amount = round(plan["price"] * 100)  # Paystack counts in cents / kobo
        await store.start_payment({
            "user_id": user.id, "reference": reference, "plan": plan["id"],
            "days": plan["days"], "amount": amount, "currency": plan["currency"],
        })
        page = await paystack(request, "POST", "/transaction/initialize", json={
            "email": user.email,
            "amount": amount,
            "currency": plan["currency"],
            "reference": reference,
            "metadata": {"plan": plan["id"]},
            **({"callback_url": f"{settings.public_url}/paid"} if settings.public_url else {}),
        })
        url = page.get("authorization_url")
        if not url:
            raise HTTPException(502, "The payment service gave no payment page. Try again later.")
        return {"reference": reference, "url": url}

    @router.get("/v1/pay/verify")
    async def verify(reference: str, request: Request, user: User = current_user):
        store: Store = request.app.state.store
        payment = await store.payment(reference, user.id)
        if payment is None:
            raise HTTPException(404, "That payment is not one of yours.")
        status = payment["status"]
        if status == "pending" and request.app.state.settings.paystack_key:
            charge = await paystack(request, "GET", f"/transaction/verify/{reference}")
            if charge.get("status") == "success":
                status = await confirm(store, charge)
            elif charge.get("status") in ("failed", "abandoned", "reversed"):
                status = "failed" if charge.get("status") != "abandoned" else "pending"
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
