"""Emails from the admin site, against a fake Supabase and a fake mailbox."""

import json
import time

import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.mailer import render, unsubscribe_code
from app.main import create_app

READY = Settings("https://db.test", "public-key", "secret-key", public_url="https://api.test/brainwake",
                 smtp_host="smtp.test", smtp_user="news@brand.test", smtp_password="pw")
NOT_SET_UP = Settings("https://db.test", "public-key", "secret-key")
BOSS = "aaaaaaaa-0000-0000-0000-000000000001"
USER = "aaaaaaaa-0000-0000-0000-000000000002"
READER = "aaaaaaaa-0000-0000-0000-000000000003"


class Mailbox:
    def __init__(self):
        self.sent, self.opened, self.closed = [], 0, 0
        self.refuse: set[str] = set()
        self.login_fails = False

    def open(self):
        if self.login_fails:
            raise RuntimeError("bad password")
        self.opened += 1

    def send(self, to, subject, text, page, unsubscribe=""):
        if to in self.refuse:
            raise ValueError("refused")
        self.sent.append({"to": to, "subject": subject, "text": text, "page": page, "unsubscribe": unsubscribe})

    def close(self):
        self.closed += 1


class World:
    def __init__(self):
        self.tokens = {"boss": (BOSS, "boss@brand.test"), "user": (USER, "user@x.test")}
        self.roles = {BOSS: "owner", USER: "user"}
        self.recipients = [{"user_id": USER, "email": "user@x.test"}, {"user_id": READER, "email": "reader@x.test"}]
        self.asked, self.campaigns, self.stopped = [], {}, []

    def handle(self, request: httpx.Request) -> httpx.Response:
        path, params = request.url.path, request.url.params
        if path == "/auth/v1/user":
            who = self.tokens.get(request.headers["authorization"].removeprefix("Bearer "))
            return httpx.Response(200, json={"id": who[0], "email": who[1]}) if who else httpx.Response(401, json={})
        assert request.headers["apikey"] == "secret-key"
        if path == "/rest/v1/profiles" and request.method == "GET":
            user = params["id"].removeprefix("eq.")
            return httpx.Response(200, json=[{"plan": "free", "plan_expires_at": None, "tier": None,
                                              "role": self.roles.get(user, "user")}])
        if path == "/rest/v1/profiles" and request.method == "PATCH":
            assert json.loads(request.content) == {"email_updates": False}
            self.stopped.append(params["id"].removeprefix("eq."))
            return httpx.Response(204)
        if path == "/rest/v1/rpc/email_recipients":
            self.asked.append(json.loads(request.content))
            return httpx.Response(200, json=self.recipients)
        if path == "/rest/v1/email_campaigns" and request.method == "POST":
            row = {**json.loads(request.content), "id": f"c{len(self.campaigns) + 1}", "status": "sending"}
            self.campaigns[row["id"]] = row
            return httpx.Response(201, json=[row])
        if path == "/rest/v1/email_campaigns" and request.method == "PATCH":
            self.campaigns[params["id"].removeprefix("eq.")].update(json.loads(request.content))
            return httpx.Response(204)
        raise AssertionError(f"unexpected Supabase call {request.method} {path}")


@pytest.fixture
def world():
    return World()


@pytest.fixture
def mailbox():
    return Mailbox()


def make(world, mailbox, settings=READY):
    http = httpx.AsyncClient(transport=httpx.MockTransport(world.handle))
    return TestClient(create_app(settings, http, mailer=mailbox, mail_gap=0))


@pytest.fixture
def client(world, mailbox):
    with make(world, mailbox) as c:
        yield c


def auth(token="boss"):
    return {"Authorization": f"Bearer {token}"}


def wait_done(world, campaign="c1"):
    for _ in range(200):
        if world.campaigns[campaign]["status"] != "sending":
            return world.campaigns[campaign]
        time.sleep(0.01)
    raise AssertionError("the emails were never finished")


EMAIL = {"subject": "Version 1.0.2 is out", "body": "Hello,\n\nA new version is ready.\nIt fixes alarms.",
         "audience": "older", "button_text": "Get it", "button_url": "https://brainoclock.onrender.com/#download"}


def test_only_admins_may_send(client, world, mailbox):
    assert client.post("/v1/admin/email/send", json=EMAIL).status_code == 401
    assert client.post("/v1/admin/email/send", json=EMAIL, headers=auth("user")).status_code == 403
    assert client.get("/v1/admin/email/status", headers=auth("user")).status_code == 403
    assert mailbox.sent == [] and world.campaigns == {}


def test_status_says_whether_the_mailbox_is_set_up(world, mailbox):
    with make(world, mailbox) as c:
        assert c.get("/v1/admin/email/status", headers=auth()).json() == {
            "ready": True, "from": "news@brand.test", "your_email": "boss@brand.test", "max_recipients": 400}
    with make(world, mailbox, NOT_SET_UP) as c:
        assert c.get("/v1/admin/email/status", headers=auth()).json()["ready"] is False
        refused = c.post("/v1/admin/email/send", json=EMAIL, headers=auth())
        assert refused.status_code == 503 and "not set up" in refused.json()["detail"]


def test_a_test_email_goes_only_to_the_admin(client, world, mailbox):
    reply = client.post("/v1/admin/email/send", json={**EMAIL, "test": True}, headers=auth())
    assert reply.json() == {"sent": 1, "to": "boss@brand.test"}
    assert [m["to"] for m in mailbox.sent] == ["boss@brand.test"]
    assert world.campaigns == {} and world.asked == []


def test_sending_writes_to_everyone_once_and_records_it(client, world, mailbox):
    reply = client.post("/v1/admin/email/send", json=EMAIL, headers=auth())
    assert reply.json() == {"campaign": "c1", "recipients": 2}
    done = wait_done(world)
    assert world.asked == [{"audience": "older", "app_version": ""}]
    assert [m["to"] for m in mailbox.sent] == ["user@x.test", "reader@x.test"]
    assert (done["sent"], done["failed"], done["status"], done["total"]) == (2, 0, "done", 2)
    assert done["created_by"] == BOSS
    assert mailbox.opened == 1 and mailbox.closed == 1
    first = mailbox.sent[0]
    assert "A new version is ready.<br>It fixes alarms." in first["page"]
    assert 'href="https://brainoclock.onrender.com/#download"' in first["page"] and "Get it" in first["page"]
    # No "stop these emails" link for now.
    assert all(m["unsubscribe"] == "" for m in mailbox.sent)
    assert "Stop these emails" not in first["page"] and "unsubscribe" not in first["text"]


def test_one_bad_address_does_not_stop_the_rest(client, world, mailbox):
    mailbox.refuse = {"user@x.test"}
    client.post("/v1/admin/email/send", json=EMAIL, headers=auth())
    done = wait_done(world)
    assert [m["to"] for m in mailbox.sent] == ["reader@x.test"]
    assert (done["sent"], done["failed"], done["status"]) == (1, 1, "done")


def test_a_mailbox_that_refuses_the_password_is_reported(client, world, mailbox):
    mailbox.login_fails = True
    test = client.post("/v1/admin/email/send", json={**EMAIL, "test": True}, headers=auth())
    assert test.status_code == 502 and "mailbox" in test.json()["detail"]
    client.post("/v1/admin/email/send", json=EMAIL, headers=auth())
    done = wait_done(world)
    assert (done["sent"], done["failed"], done["status"]) == (0, 2, "stopped")
    assert "pw" not in json.dumps(done)


def test_typed_addresses_and_the_checks(client, world, mailbox):
    typed = {"subject": "Hello there", "body": "A note.", "audience": "custom",
             "emails": ["a@x.test", "A@x.test", "b@x.test"]}
    assert client.post("/v1/admin/email/send", json=typed, headers=auth()).json()["recipients"] == 2
    wait_done(world)
    assert [m["to"] for m in mailbox.sent] == ["a@x.test", "b@x.test"]
    assert mailbox.sent[0]["unsubscribe"] == ""  # not an account: no link to offer

    def refused(**changes):
        return client.post("/v1/admin/email/send", json={**EMAIL, **changes}, headers=auth()).status_code

    assert refused(audience="custom", emails=["not an address"]) == 422
    assert refused(audience="everyone") == 422
    assert refused(audience="version") == 422          # no version chosen
    assert refused(button_url="") == 422               # text without address
    assert refused(button_url="http://plain.test") == 422
    world.recipients = []
    assert refused() == 422                            # nobody matches
    world.recipients = [{"user_id": None, "email": f"p{i}@x.test"} for i in range(401)]
    assert refused() == 422                            # more than a day's worth


def test_unsubscribe_needs_the_right_code(client, world):
    good = unsubscribe_code("secret-key", USER)
    assert client.get(f"/unsubscribe?u={USER}&c=wrong").status_code == 404
    assert client.get(f"/unsubscribe?u=someone&c={good}").status_code == 404
    assert world.stopped == []
    page = client.get(f"/unsubscribe?u={USER}&c={good}")
    assert page.status_code == 200 and "will not get any more" in page.text
    assert world.stopped == [USER]


def test_the_message_cannot_smuggle_html():
    text, page = render("5 < 6", "<script>alert(1)</script>\n\nSecond & last", "Go", "https://x.test/?a=1&b=2", "")
    assert "<script>" not in page and "&lt;script&gt;" in page
    assert "Second &amp; last" in page and "5 &lt; 6" in page
    assert "<script>alert(1)</script>" in text and "Go: https://x.test/?a=1&b=2" in text
    assert "Stop these emails" not in page
