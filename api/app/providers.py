"""Sends one prompt to an AI provider and returns the JSON it wrote.

Three request formats cover every service: "openai" (OpenAI, Groq,
OpenRouter and anything compatible), "gemini" (Google) and "anthropic".
`ask` walks through the saved providers in round-robin order and moves on to
the next when one fails.
"""

import json
import logging

import httpx

from .store import Provider, Store

log = logging.getLogger("brainwake.providers")

DEFAULT_ENDPOINT = {
    "openai": "https://api.openai.com/v1",
    "gemini": "https://generativelanguage.googleapis.com/v1beta",
    "anthropic": "https://api.anthropic.com/v1",
}
MAX_PROVIDERS_PER_REQUEST = 3


class ProviderError(Exception):
    """One provider failed; the text is safe to show the owner."""


class NoProviderError(Exception):
    """No provider is switched on, or every one that was tried failed."""


def extract_json(text: str):
    """Reads JSON out of a model reply, tolerating code fences or chatter
    around it."""
    text = text.strip()
    try:
        return json.loads(text)
    except ValueError:
        pass
    for opener, closer in (("{", "}"), ("[", "]")):
        start, end = text.find(opener), text.rfind(closer)
        if start != -1 and end > start:
            try:
                return json.loads(text[start : end + 1])
            except ValueError:
                continue
    raise ProviderError("The reply was not valid JSON")


def _scrub(text: str, secret: str) -> str:
    return text.replace(secret, "[key]") if secret else text


async def call_provider(
    http: httpx.AsyncClient,
    provider: Provider,
    system: str,
    prompt: str,
    *,
    timeout: float,
    max_tokens: int,
):
    """One request to one provider. Returns parsed JSON or raises ProviderError."""
    base = (provider.endpoint or DEFAULT_ENDPOINT[provider.type]).rstrip("/")
    key = provider.api_key

    if provider.type == "gemini":
        url = f"{base}/models/{provider.model}:generateContent"
        headers = {"x-goog-api-key": key}
        body = {
            "system_instruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {"responseMimeType": "application/json", "maxOutputTokens": max_tokens},
        }
    elif provider.type == "anthropic":
        url = f"{base}/messages"
        headers = {"x-api-key": key, "anthropic-version": "2023-06-01"}
        body = {
            "model": provider.model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": [{"role": "user", "content": prompt}],
        }
    else:
        url = f"{base}/chat/completions"
        headers = {"Authorization": f"Bearer {key}"}
        body = {
            "model": provider.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": prompt},
            ],
            "response_format": {"type": "json_object"},
        }

    async def send(payload: dict) -> httpx.Response:
        try:
            return await http.post(url, headers=headers, json=payload, timeout=timeout)
        except httpx.TimeoutException as error:
            raise ProviderError(f"No reply within {timeout:.0f} seconds") from error
        except httpx.HTTPError as error:
            raise ProviderError(f"Could not connect ({type(error).__name__})") from error

    response = await send(body)
    # Some OpenAI-compatible services do not know "response_format".
    if response.status_code == 400 and "response_format" in body and "response_format" in response.text:
        body.pop("response_format")
        response = await send(body)
    if response.status_code != 200:
        detail = _scrub(" ".join(response.text.split())[:300], key)
        raise ProviderError(f"The provider answered {response.status_code}: {detail}")

    try:
        data = response.json()
        if provider.type == "gemini":
            text = "".join(p.get("text", "") for p in data["candidates"][0]["content"]["parts"])
        elif provider.type == "anthropic":
            text = "".join(p.get("text", "") for p in data["content"])
        else:
            text = data["choices"][0]["message"]["content"] or ""
    except (ValueError, KeyError, IndexError, TypeError) as error:
        raise ProviderError("The reply had an unexpected shape") from error
    return extract_json(text)


async def ask(
    store: Store,
    http: httpx.AsyncClient,
    system: str,
    prompt: str,
    *,
    timeout: float,
    max_tokens: int = 4096,
    check=None,
):
    """Asks the providers in turn until one gives a usable answer.

    `check(data)` may turn the parsed JSON into the final result, raising
    ProviderError if it is not usable (so the next provider gets a try).
    """
    skip: list[str] = []
    for _ in range(MAX_PROVIDERS_PER_REQUEST):
        provider = await store.pick_provider(skip)
        if provider is None:
            break
        try:
            data = await call_provider(
                http, provider, system, prompt, timeout=timeout, max_tokens=max_tokens
            )
            return check(data) if check else data
        except ProviderError as error:
            log.warning("provider %s failed: %s", provider.name, error)
            await store.report_provider_error(provider.id, str(error))
            skip.append(provider.id)
    raise NoProviderError("No AI provider is available" if not skip else "Every AI provider failed")
