"""The web server: checks the caller, enforces limits, runs the AI task.

    GET  /health            is the server up (no sign-in)
    GET  /v1/ai/status      the caller's AI allowance for today
    POST /v1/ai/generate    write new questions on a subject
    POST /v1/ai/feedback    explain an answer to the student
    POST /v1/ai/grade       is this typed answer right (not limited per day)

Every /v1 call needs "Authorization: Bearer <the user's Supabase token>".
Run: uvicorn app.main:app
"""

import logging
import time
from collections import defaultdict, deque
from contextlib import asynccontextmanager
from typing import Annotated

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, StringConstraints

from . import tasks
from .config import Settings
from .providers import NoProviderError, ask
from .store import Store, StoreError, User

log = logging.getLogger("brainwake.api")

REQUESTS_PER_MINUTE = 30

Short = Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)]
Long = Annotated[str, StringConstraints(strip_whitespace=True, max_length=2000)]


class GenerateRequest(BaseModel):
    subject: Annotated[str, StringConstraints(strip_whitespace=True, min_length=2, max_length=200)]
    count: int = Field(5, ge=1, le=10)
    avoid: list[Long] = Field(default_factory=list, max_length=40)


class FeedbackRequest(BaseModel):
    question: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)]
    options: list[Short] = Field(default_factory=list, max_length=8)
    correct_answer: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=300)]
    explanation: Long = ""
    user_answer: Short = ""
    known_verdict: bool | None = None


class GradeRequest(BaseModel):
    question: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)]
    correct_answer: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=300)]
    user_answer: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=300)]


def create_app(settings: Settings | None = None, http: httpx.AsyncClient | None = None) -> FastAPI:
    """Builds the server. Tests pass their own settings and a fake network."""

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.http = http or httpx.AsyncClient()
        app.state.store = Store(settings or Settings.from_env(), app.state.http)
        app.state.recent = defaultdict(deque)  # user id -> times of recent calls
        yield
        if http is None:
            await app.state.http.aclose()

    app = FastAPI(title="BrainWake API", lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)

    @app.exception_handler(StoreError)
    async def store_down(_: Request, error: StoreError):
        log.error("store: %s", error)
        return JSONResponse({"detail": "The server could not reach its database. Try again shortly."}, 503)

    @app.exception_handler(NoProviderError)
    async def no_provider(_: Request, error: NoProviderError):
        log.error("ai: %s", error)
        return JSONResponse({"detail": "The AI is not available right now. Try again later."}, 503)

    async def current_user(request: Request, authorization: str = Header("")) -> User:
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token.strip():
            raise HTTPException(401, "Sign in to use AI features.")
        user = await request.app.state.store.user_for_token(token.strip())
        if user is None:
            raise HTTPException(401, "Your sign-in has expired. Sign in again.")
        # A simple brake on runaway clients, per user.
        calls = request.app.state.recent[user.id]
        now = time.monotonic()
        while calls and calls[0] < now - 60:
            calls.popleft()
        if len(calls) >= REQUESTS_PER_MINUTE:
            raise HTTPException(429, "Too many requests. Wait a minute and try again.")
        calls.append(now)
        return user

    Caller = Annotated[User, Depends(current_user)]

    async def allowance(store: Store, user: User) -> dict:
        config = await store.config()
        limit = config.get("ai_daily_limit_premium" if user.premium else "ai_daily_limit_free", 0)
        limit = limit if isinstance(limit, int) and limit > 0 else 0
        used = await store.used_today(user.id)
        return {
            "enabled": config.get("ai_enabled") is not False,
            "plan": "premium" if user.premium else "free",
            "limit": limit,
            "used": used,
            "remaining": max(0, limit - used),
        }

    async def require_allowance(store: Store, user: User, counted: bool) -> dict:
        if not counted:
            config = await store.config()
            if config.get("ai_enabled") is False:
                raise HTTPException(503, "AI features are switched off for now.")
            return {}
        status = await allowance(store, user)
        if not status["enabled"]:
            raise HTTPException(503, "AI features are switched off for now.")
        if status["remaining"] <= 0:
            raise HTTPException(429, f"You have used today's {status['limit']} AI requests. They reset at midnight UTC.")
        return status

    async def finish(store: Store, user: User, kind: str, status: dict) -> int | None:
        """Records a successful call; returns what is left today, if counted."""
        try:
            await store.record_use(user.id, kind)
        except StoreError as error:
            log.error("could not record AI use: %s", error)
        return status["remaining"] - 1 if status else None

    @app.get("/health")
    async def health():
        return {"ok": True}

    @app.get("/v1/ai/status")
    async def ai_status(request: Request, user: Caller):
        return await allowance(request.app.state.store, user)

    @app.post("/v1/ai/generate")
    async def generate(body: GenerateRequest, request: Request, user: Caller):
        store = request.app.state.store
        status = await require_allowance(store, user, counted=True)
        questions = await ask(
            store, request.app.state.http, tasks.SYSTEM,
            tasks.generate_prompt(body.subject, body.count, body.avoid),
            timeout=60, max_tokens=8192, check=tasks.check_generated(body.count),
        )
        return {"questions": questions, "remaining": await finish(store, user, "generate", status)}

    @app.post("/v1/ai/feedback")
    async def feedback(body: FeedbackRequest, request: Request, user: Caller):
        store = request.app.state.store
        status = await require_allowance(store, user, counted=True)
        result = await ask(
            store, request.app.state.http, tasks.SYSTEM,
            tasks.feedback_prompt(body.question, body.options, body.correct_answer,
                                  body.explanation, body.user_answer, body.known_verdict),
            timeout=25, max_tokens=1024, check=tasks.check_feedback,
        )
        if not body.user_answer:
            result["correct"] = False
        elif body.known_verdict is not None:
            result["correct"] = body.known_verdict
        return {**result, "remaining": await finish(store, user, "feedback", status)}

    @app.post("/v1/ai/grade")
    async def grade(body: GradeRequest, request: Request, user: Caller):
        store = request.app.state.store
        await require_allowance(store, user, counted=False)
        correct = await ask(
            store, request.app.state.http, tasks.SYSTEM,
            tasks.grade_prompt(body.question, body.correct_answer, body.user_answer),
            timeout=6, max_tokens=64, check=tasks.check_grade,
        )
        await finish(store, user, "grade", {})
        return {"correct": correct}

    return app


def app() -> FastAPI:  # uvicorn app.main:app --factory
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)  # its lines include request addresses
    return create_app()
