"""Buying premium, against a fake Supabase and a fake Paystack (no network)."""

import hashlib
import hmac
import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.test_api import World, auth

SECRET = "sk_test_secret"
SETTINGS = Settings("https://db.test", "public-key", "secret-key", paystack_key=SECRET,
                    public_url="https://api.test/brainwake")


class Shop(World):
    """The pretend world, plus a payments table and Paystack."""

    def __init__(self):
        super().__init__()
        self.config.update({"payments_enabled": True, "premium_currency": "KES",
                            "premium_price_month": 300, "premium_price_year": 2500})
        self.emails = {"user-1": "one@example.com", "user-2": "two@example.com"}
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
                    self.profiles[row["user_id"]] = {"plan": "premium", "plan_expires_at": None}
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


def test_plans_show_prices_and_the_callers_plan(client):
    data = client.get("/v1/pay/plans", headers=auth()).json()
    assert data["enabled"] is True and data["premium"] is False
    assert data["plans"] == [
        {"id": "month", "days": 30, "price": 300, "currency": "KES"},
        {"id": "year", "days": 365, "price": 2500, "currency": "KES"}]


def test_starting_a_payment_uses_the_servers_price_not_the_apps(client, shop):
    response = client.post("/v1/pay/start", headers=auth(), json={"plan": "year", "amount": 1})
    assert response.status_code == 200, response.text
    sent = json.loads(shop.paystack_calls[0].content)
    assert sent["amount"] == 250000 and sent["currency"] == "KES"      # in cents
    assert sent["email"] == "one@example.com"
    assert sent["callback_url"] == "https://api.test/brainwake/paid"
    row = shop.payments[0]
    assert row["user_id"] == "user-1" and row["days"] == 365 and row["amount"] == 250000
    assert response.json() == {"reference": row["reference"], "url": f"https://checkout.paystack.com/{row['reference']}"}


def test_a_signed_message_from_paystack_gives_premium_once(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={"plan": "month"}).json()["reference"]
    body = json.dumps({"event": "charge.success", "data": {
        "reference": reference, "amount": 30000, "currency": "KES", "channel": "card"}}).encode()
    for _ in range(2):   # Paystack repeats its messages
        assert client.post("/v1/pay/webhook", content=body, headers=signed(body)).status_code == 200
    assert shop.payments[0]["status"] == "paid"
    assert client.get("/v1/pay/plans", headers=auth()).json()["premium"] is True


def test_a_forged_message_is_refused(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={"plan": "month"}).json()["reference"]
    body = json.dumps({"event": "charge.success", "data": {
        "reference": reference, "amount": 30000, "currency": "KES"}}).encode()
    assert client.post("/v1/pay/webhook", content=body, headers=signed(body, "wrong-key")).status_code == 401
    assert client.post("/v1/pay/webhook", content=body).status_code == 401
    assert shop.payments[0]["status"] == "pending"


def test_paying_less_than_the_price_buys_nothing(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={"plan": "year"}).json()["reference"]
    body = json.dumps({"event": "charge.success", "data": {
        "reference": reference, "amount": 100, "currency": "KES"}}).encode()
    client.post("/v1/pay/webhook", content=body, headers=signed(body))
    assert shop.payments[0]["status"] == "failed"
    assert client.get("/v1/pay/plans", headers=auth()).json()["premium"] is False


def test_the_app_can_check_a_payment_when_the_user_returns(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={"plan": "month"}).json()["reference"]
    shop.charge_status = "abandoned"
    assert client.get(f"/v1/pay/verify?reference={reference}", headers=auth()).json()["status"] == "pending"
    shop.charge_status = "success"
    data = client.get(f"/v1/pay/verify?reference={reference}", headers=auth()).json()
    assert data["status"] == "paid" and data["premium"] is True
    # Premium takes effect at once for the AI limit too.
    assert client.get("/v1/ai/status", headers=auth()).json()["plan"] == "premium"


def test_nobody_can_check_or_claim_someone_elses_payment(client, shop):
    reference = client.post("/v1/pay/start", headers=auth(), json={"plan": "month"}).json()["reference"]
    assert client.get(f"/v1/pay/verify?reference={reference}", headers=auth("rich")).status_code == 404
    assert shop.profiles["user-2"]["plan"] == "premium"   # unchanged (was premium in the fixture)
    assert shop.profiles["user-1"]["plan"] == "free"


def test_switched_off_or_unknown_plans(client, shop):
    assert client.post("/v1/pay/start", headers=auth(), json={"plan": "decade"}).status_code == 422
    shop.config["payments_enabled"] = False
    client.app.state.store._config = None
    assert client.get("/v1/pay/plans", headers=auth()).json()["enabled"] is False
    assert client.post("/v1/pay/start", headers=auth(), json={"plan": "month"}).status_code == 503
    assert shop.payments == []


def test_sign_in_is_needed_to_buy(client):
    assert client.get("/v1/pay/plans").status_code == 401
    assert client.post("/v1/pay/start", json={"plan": "month"}).status_code == 401


def test_the_thank_you_page(client):
    assert "Go back to the app" in client.get("/paid").text
