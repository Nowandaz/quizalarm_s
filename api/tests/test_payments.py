"""Buying a tier, against a fake Supabase and a fake Paystack (no network)."""

import hashlib
import hmac
import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.payments import kenyan_phone
from tests.test_api import World, auth

SECRET = "sk_test_secret"
SETTINGS = Settings("https://db.test", "public-key", "secret-key", paystack_key=SECRET,
                    public_url="https://api.test/brainwake")


class Shop(World):
    """The pretend world, plus tiers, codes, a payments table and Paystack."""

    def __init__(self):
        super().__init__()
        self.config.update({"payments_enabled": True, "premium_currency": "KES"})
        self.emails = {"user-1": "one@example.com", "user-2": "two@example.com"}
        self.tiers = [
            {"id": "pro", "name": "Pro", "description": "More of everything.", "features": ["All units"],
             "price_month": 300, "price_year": 2500, "ai_daily_limit": 150, "premium_units": True,
             "sort_order": 1, "active": True},
            {"id": "max", "name": "Max", "description": "The lot.", "features": [],
             "price_month": 800, "price_year": None, "ai_daily_limit": 500, "premium_units": True,
             "sort_order": 2, "active": True},
            {"id": "old", "name": "Old", "description": "", "features": [],
             "price_month": 50, "price_year": None, "ai_daily_limit": 10, "premium_units": False,
             "sort_order": 3, "active": False},
        ]
        self.codes = {"HALF": 50, "GIFT": 100}
        self.payments: list[dict] = []
        self.paystack_calls: list[httpx.Request] = []
        self.charge_status = "success"

    def handle(self, request: httpx.Request) -> httpx.Response:
        if request.url.host == "api.paystack.co":
            self.paystack_calls.append(request)
            assert request.headers["authorization"] == f"Bearer {SECRET}"
            if request.url.path == "/transaction/initialize":
                sent = json.loads(request.content)
                return httpx.Response(200, json={"status": True, "data": {
                    "authorization_url": f"https://checkout.paystack.com/{sent['reference']}"}})
            if request.url.path == "/charge":
                return httpx.Response(200, json={"status": True, "data": {"status": "pay_offline"}})
            reference = request.url.path.rsplit("/", 1)[1]
            row = next(p for p in self.payments if p["reference"] == reference)
            return httpx.Response(200, json={"status": True, "data": {
                "status": self.charge_status, "reference": reference,
                "amount": row["amount"], "currency": row["currency"], "channel": "mobile_money"}})
        return super().handle(request)

    def supabase(self, request: httpx.Request, path: str) -> httpx.Response:
        if path == "/auth/v1/user":
            user = self.tokens.get(request.headers["authorization"].removeprefix("Bearer "))
            if not user:
                return httpx.Response(401, json={})
            return httpx.Response(200, json={"id": user, "email": self.emails[user]})
        if path == "/rest/v1/tiers":
            return httpx.Response(200, json=self.tiers)
        if path == "/rest/v1/rpc/quote_payment":
            call = json.loads(request.content)
            tier = next((t for t in self.tiers if t["id"] == call["want_tier"] and t["active"]), None)
            full = tier and tier.get(f"price_{call['want_period']}")
            if not full:
                return httpx.Response(200, json={"ok": False, "message": "That plan is not on sale."})
            typed = call["want_code"].strip().upper()
            percent = self.codes.get(typed, 0)
            return httpx.Response(200, json={
                "ok": True, "tier": tier["id"], "tier_name": tier["name"], "period": call["want_period"],
                "days": 30 if call["want_period"] == "month" else 365, "currency": "KES",
                "full_price": full, "price": full * (100 - percent) / 100, "percent_off": percent,
                "code": typed if percent else "",
                "code_message": "" if percent or not typed else "That code is not valid."})
        if path == "/rest/v1/payments" and request.method == "POST":
            self.payments.append({**json.loads(request.content), "status": "pending"})
            return httpx.Response(201)
        if path == "/rest/v1/payments":
            params = request.url.params
            rows = [p for p in self.payments
                    if f"eq.{p['reference']}" == params["reference"] and f"eq.{p['user_id']}" == params["user_id"]]
            return httpx.Response(200, json=rows)
        if path == "/rest/v1/rpc/apply_payment":
            call = json.loads(request.content)
            row = next((p for p in self.payments if p["reference"] == call["pay_reference"]), None)
            if row is None:
                return httpx.Response(200, json="unknown")
            if row["status"] != "paid":
                if call["paid_amount"] < row["amount"] or call["paid_currency"].upper() != row["currency"]:
                    row["status"] = "failed"
                else:
                    row["status"] = "paid"
                    self.profiles[row["user_id"]] = {"plan": "premium", "plan_expires_at": None, "tier": row["tier"]}
            return httpx.Response(200, json=row["status"])
        return super().supabase(request, path)


@pytest.fixture
def shop():
    return Shop()


@pytest.fixture
def client(shop):
    http = httpx.AsyncClient(transport=httpx.MockTransport(shop.handle))
    with TestClient(create_app(SETTINGS, http)) as test_client:
        yield test_client


def signed(body: bytes, secret: str = SECRET) -> dict:
    return {"x-paystack-signature": hmac.new(secret.encode(), body, hashlib.sha512).hexdigest(),
            "content-type": "application/json"}


PRO_MONTH = {"tier": "pro", "period": "month"}


def test_plans_list_the_tiers_on_sale_and_the_callers_plan(client):
    data = client.get("/v1/pay/plans", headers=auth()).json()
    assert data["enabled"] is True and data["currency"] == "KES" and data["methods"] == ["mpesa", "card"]
    assert [t["name"] for t in data["tiers"]] == ["Pro", "Max"]          # the switched-off tier is not sold
    assert data["tiers"][0]["options"] == [
        {"period": "month", "days": 30, "price": 300.0}, {"period": "year", "days": 365, "price": 2500.0}]
    assert data["tiers"][1]["options"] == [{"period": "month", "days": 30, "price": 800.0}]
    assert data["premium"] is False and data["tier"] == ""


def test_a_quote_applies_a_code_or_says_why_not(client):
    good = client.post("/v1/pay/quote", headers=auth(), json={**PRO_MONTH, "code": "half"}).json()
    assert good["price"] == 150 and good["full_price"] == 300 and good["percent_off"] == 50 and good["code"] == "HALF"
    bad = client.post("/v1/pay/quote", headers=auth(), json={**PRO_MONTH, "code": "nope"}).json()
    assert bad["price"] == 300 and bad["code"] == "" and bad["code_message"] == "That code is not valid."
    assert client.post("/v1/pay/quote", headers=auth(), json={"tier": "max", "period": "year"}).status_code == 422


def test_mpesa_sends_a_prompt_to_the_phone_at_the_servers_price(client, shop):
    response = client.post("/v1/pay/start", headers=auth(), json={
        **PRO_MONTH, "method": "mpesa", "phone": "0712 345 678", "amount": 1})
    assert response.status_code == 200, response.text
    sent = json.loads(shop.paystack_calls[0].content)
    assert shop.paystack_calls[0].url.path == "/charge"
    assert sent["amount"] == 30000 and sent["currency"] == "KES"          # in cents, from the tier
    assert sent["mobile_money"] == {"phone": "+254712345678", "provider": "mpesa"}
    assert sent["email"] == "one@example.com"
    data = response.json()
    assert data["status"] == "pending" and "+254712345678" in data["message"]
    row = shop.payments[0]
    assert row["tier"] == "pro" and row["days"] == 30 and row["amount"] == 30000 and row["code"] is None


def test_a_bad_phone_number_is_refused_before_anything_is_charged(client, shop):
    response = client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "mpesa", "phone": "12345"})
    assert response.status_code == 422 and "M-Pesa number" in response.json()["detail"]
    assert shop.payments == [] and shop.paystack_calls == []


def test_card_returns_paystacks_page_limited_to_cards(client, shop):
    response = client.post("/v1/pay/start", headers=auth(), json={"tier": "pro", "period": "year", "method": "card", "code": "HALF"})
    assert response.status_code == 200, response.text
    sent = json.loads(shop.paystack_calls[0].content)
    assert sent["amount"] == 125000 and sent["channels"] == ["card"]
    assert sent["callback_url"] == "https://api.test/brainwake/paid"
    row = shop.payments[0]
    assert row["amount"] == 125000 and row["full_amount"] == 250000 and row["code"] == "HALF" and row["days"] == 365
    data = response.json()
    assert data["url"] == f"https://checkout.paystack.com/{row['reference']}"
    assert data["done_url"] == "https://api.test/brainwake/paid"


def test_a_code_that_does_not_work_stops_the_payment(client, shop):
    response = client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "card", "code": "NOPE"})
    assert response.status_code == 422 and response.json()["detail"] == "That code is not valid."
    assert shop.payments == []


def test_a_full_discount_code_grants_the_tier_without_paystack(client, shop):
    data = client.post("/v1/pay/start", headers=auth(), json={"tier": "max", "period": "month", "code": "gift"}).json()
    assert data["status"] == "paid" and data["premium"] is True and data["tier"] == "max" and data["tier_name"] == "Max"
    assert shop.paystack_calls == []
    assert shop.payments[0]["amount"] == 0 and shop.payments[0]["code"] == "GIFT"


def test_a_signed_message_from_paystack_gives_the_tier_once(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "card"}).json()["reference"]
    body = json.dumps({"event": "charge.success", "data": {
        "reference": reference, "amount": 30000, "currency": "KES", "channel": "card"}}).encode()
    for _ in range(2):   # Paystack repeats its messages
        assert client.post("/v1/pay/webhook", content=body, headers=signed(body)).status_code == 200
    assert shop.payments[0]["status"] == "paid"
    plan = client.get("/v1/pay/plans", headers=auth()).json()
    assert plan["premium"] is True and plan["tier_name"] == "Pro"


def test_a_forged_message_is_refused(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "card"}).json()["reference"]
    body = json.dumps({"event": "charge.success", "data": {
        "reference": reference, "amount": 30000, "currency": "KES"}}).encode()
    assert client.post("/v1/pay/webhook", content=body, headers=signed(body, "wrong-key")).status_code == 401
    assert client.post("/v1/pay/webhook", content=body).status_code == 401
    assert shop.payments[0]["status"] == "pending"


def test_paying_less_than_the_price_buys_nothing(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={"tier": "pro", "period": "year", "method": "card"}).json()["reference"]
    body = json.dumps({"event": "charge.success", "data": {
        "reference": reference, "amount": 100, "currency": "KES"}}).encode()
    client.post("/v1/pay/webhook", content=body, headers=signed(body))
    assert shop.payments[0]["status"] == "failed"
    assert client.get("/v1/pay/plans", headers=auth()).json()["premium"] is False


def test_the_app_polls_until_the_mpesa_prompt_is_approved(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={
        **PRO_MONTH, "method": "mpesa", "phone": "254712345678"}).json()["reference"]
    shop.charge_status = "ongoing"
    assert client.get(f"/v1/pay/verify?reference={reference}", headers=auth()).json()["status"] == "pending"
    shop.charge_status = "success"
    data = client.get(f"/v1/pay/verify?reference={reference}", headers=auth()).json()
    assert data["status"] == "paid" and data["premium"] is True and data["tier"] == "pro"
    # The tier's own AI allowance applies at once.
    status = client.get("/v1/ai/status", headers=auth()).json()
    assert status["plan"] == "premium" and status["limit"] == 150


def test_a_declined_payment_is_reported_as_failed(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "card"}).json()["reference"]
    shop.charge_status = "failed"
    assert client.get(f"/v1/pay/verify?reference={reference}", headers=auth()).json()["status"] == "failed"


def test_nobody_can_check_someone_elses_payment(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "card"}).json()["reference"]
    assert client.get(f"/v1/pay/verify?reference={reference}", headers=auth("rich")).status_code == 404
    assert shop.profiles["user-1"]["plan"] == "free"


def test_switched_off_unknown_or_unsold(client, shop):
    assert client.post("/v1/pay/start", headers=auth(), json={"tier": "nope", "period": "month"}).status_code == 422
    assert client.post("/v1/pay/start", headers=auth(), json={"tier": "old", "period": "month"}).status_code == 422
    assert client.post("/v1/pay/start", headers=auth(), json={"tier": "pro", "period": "decade"}).status_code == 422
    shop.config["payments_enabled"] = False
    client.app.state.store._config = None
    assert client.get("/v1/pay/plans", headers=auth()).json()["enabled"] is False
    assert client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "card"}).status_code == 503
    assert shop.payments == []


def test_mpesa_is_offered_for_kenyan_shillings_only(client, shop):
    shop.config["premium_currency"] = "USD"
    assert client.get("/v1/pay/plans", headers=auth()).json()["methods"] == ["card"]
    response = client.post("/v1/pay/start", headers=auth(), json={**PRO_MONTH, "method": "mpesa", "phone": "0712345678"})
    assert response.status_code == 422


def test_sign_in_is_needed_to_buy(client):
    assert client.get("/v1/pay/plans").status_code == 401
    assert client.post("/v1/pay/start", json=PRO_MONTH).status_code == 401
    assert client.post("/v1/pay/quote", json=PRO_MONTH).status_code == 401


def test_phone_numbers_as_people_type_them():
    for typed in ("0712345678", "0712 345 678", "+254 712 345678", "254712345678", "712345678", "0110123456"):
        assert kenyan_phone(typed) in ("+254712345678", "+254110123456"), typed
    for typed in ("", "12345", "0812345678", "07123456789", "abc"):
        assert kenyan_phone(typed) is None, typed


def test_the_thank_you_page(client):
    assert "Go back to the app" in client.get("/paid").text
